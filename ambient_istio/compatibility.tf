locals {
  kubernetes_validation_enabled = var.kubernetes_compatibility != "skip"
}

data "http" "istio_support_status" {
  count = local.kubernetes_validation_enabled ? 1 : 0
  url   = "https://raw.githubusercontent.com/istio/istio.io/master/data/compatibility/supportStatus.yml"

  request_headers = {
    Accept = "application/x-yaml"
  }
}

locals {
  istio_support_matrix = local.kubernetes_validation_enabled ? try(
    yamldecode(try(data.http.istio_support_status[0].response_body, "")),
    [],
  ) : []

  istio_version_parts = split(".", trimprefix(trimspace(var.istio_version), "v"))
  istio_minor_version = format(
    "%d.%d",
    tonumber(local.istio_version_parts[0]),
    tonumber(local.istio_version_parts[1]),
  )

  effective_kubernetes_version = trimspace(var.plugin.cluster_version)

  effective_kubernetes_parts = split(".", trimprefix(local.effective_kubernetes_version, "v"))
  effective_kubernetes_minor_version = format(
    "%d.%d",
    tonumber(local.effective_kubernetes_parts[0]),
    tonumber(local.effective_kubernetes_parts[1]),
  )

  istio_support_entries_for_minor = [
    for entry in local.istio_support_matrix : entry
    if try(entry.version, null) == local.istio_minor_version
  ]
  selected_istio_support_entry = try(local.istio_support_entries_for_minor[0], null)

  kubernetes_versions_from_matrix = local.selected_istio_support_entry == null ? [] : (
    var.kubernetes_compatibility == "tested"
    ? distinct(concat(
      try(local.selected_istio_support_entry.k8sVersions, []),
      try(local.selected_istio_support_entry.testedK8sVersions, []),
    ))
    : try(local.selected_istio_support_entry.k8sVersions, [])
  )

  allowed_kubernetes_minor_versions = distinct(compact([
    for version in local.kubernetes_versions_from_matrix : (
      can(tonumber(try(split(".", trimprefix(trimspace(tostring(version)), "v"))[0], ""))) &&
      can(tonumber(try(split(".", trimprefix(trimspace(tostring(version)), "v"))[1], "")))
      ) ? format(
      "%d.%d",
      tonumber(split(".", trimprefix(trimspace(tostring(version)), "v"))[0]),
      tonumber(split(".", trimprefix(trimspace(tostring(version)), "v"))[1]),
    ) : null
  ]))

  is_kubernetes_version_compatible = contains(local.allowed_kubernetes_minor_versions, local.effective_kubernetes_minor_version)
}

resource "terraform_data" "kubernetes_compatibility_guard" {
  count = local.kubernetes_validation_enabled ? 1 : 0

  input = {
    istio_version                = var.istio_version
    istio_minor_version          = local.istio_minor_version
    effective_kubernetes_version = local.effective_kubernetes_version
    kubernetes_compatibility     = var.kubernetes_compatibility
  }

  lifecycle {
    precondition {
      condition     = local.selected_istio_support_entry != null
      error_message = "Istio minor version was not found in upstream supportStatus.yml. Use kubernetes_compatibility=\"skip\" to bypass validation (for example for prerelease Istio builds)."
    }

    precondition {
      condition = local.selected_istio_support_entry != null && local.is_kubernetes_version_compatible
      error_message = format(
        "Kubernetes version '%s' is not compatible with Istio %s in mode '%s'. Allowed Kubernetes versions: %s. Use kubernetes_compatibility=\"skip\" to bypass this check.",
        local.effective_kubernetes_minor_version,
        local.istio_minor_version,
        var.kubernetes_compatibility,
        length(local.allowed_kubernetes_minor_versions) > 0 ? join(", ", local.allowed_kubernetes_minor_versions) : "none",
      )
    }
  }
}
