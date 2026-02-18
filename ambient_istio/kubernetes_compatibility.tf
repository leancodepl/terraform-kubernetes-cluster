# compatibility.kubernetes.mode:
# - supported: allow only Kubernetes versions listed by Istio as supported (k8sVersions).
# - tested: also allow tested-only versions (k8sVersions + testedK8sVersions), which is broader.
# - skip: do not enforce Kubernetes compatibility matrix checks.
locals {
  istio_support_status_http_status = try(data.http.istio_support_status[0].status_code, null)
  istio_support_matrix = local.kubernetes_validation_enabled ? try(
    yamldecode(data.http.istio_support_status[0].response_body),
    [],
  ) : []

  istio_support_entries_for_minor = [
    for entry in local.istio_support_matrix : entry
    if try(entry.version, null) == local.istio_minor_version
  ]
  selected_istio_support_entry = try(local.istio_support_entries_for_minor[0], null)

  kubernetes_versions_from_matrix = local.selected_istio_support_entry == null ? [] : (
    var.compatibility.kubernetes.mode == "tested"
    ? distinct(concat(
      try(local.selected_istio_support_entry.k8sVersions, []),
      try(local.selected_istio_support_entry.testedK8sVersions, []),
    ))
    : try(local.selected_istio_support_entry.k8sVersions, [])
  )

  kubernetes_matrix_versions_normalized = [
    for version in local.kubernetes_versions_from_matrix : trimprefix(trimspace(tostring(version)), "v")
  ]
  allowed_kubernetes_minor_versions = distinct(compact([
    for version in local.kubernetes_matrix_versions_normalized : (
      can(tonumber(try(split(".", version)[0], ""))) &&
      can(tonumber(try(split(".", version)[1], "")))
      ) ? format(
      "%d.%d",
      tonumber(split(".", version)[0]),
      tonumber(split(".", version)[1]),
    ) : null
  ]))

  is_kubernetes_version_compatible = contains(local.allowed_kubernetes_minor_versions, local.effective_kubernetes_minor_version)
}

data "http" "istio_support_status" {
  count = local.kubernetes_validation_enabled ? 1 : 0
  url   = var.compatibility.kubernetes.support_status_url

  request_headers = {
    Accept = "application/x-yaml"
  }
}

resource "terraform_data" "kubernetes_compatibility_guard" {
  count = local.kubernetes_validation_enabled ? 1 : 0

  input = {
    istio_version                = local.istio_chart_version
    istio_minor_version          = local.istio_minor_version
    effective_kubernetes_version = local.effective_kubernetes_version
    kubernetes_compatibility     = var.compatibility.kubernetes.mode
  }

  lifecycle {
    precondition {
      condition = local.istio_support_status_http_status == 200
      error_message = format(
        "Failed to fetch Istio support matrix from %s (HTTP status: %s). Set compatibility.kubernetes.mode = \"skip\" to bypass validation.",
        var.compatibility.kubernetes.support_status_url,
        local.istio_support_status_http_status == null ? "unknown" : tostring(local.istio_support_status_http_status),
      )
    }

    precondition {
      condition = local.selected_istio_support_entry != null
      error_message = format(
        "Istio minor version %s was not found in support matrix from %s. Set compatibility.kubernetes.mode = \"skip\" to bypass validation (for example for prerelease Istio builds).",
        local.istio_minor_version,
        var.compatibility.kubernetes.support_status_url,
      )
    }

    precondition {
      condition = local.is_kubernetes_version_compatible
      error_message = format(
        "Kubernetes version '%s' is not compatible with Istio %s in mode '%s'. Allowed Kubernetes versions: %s. Set compatibility.kubernetes.mode = \"skip\" to bypass this check.",
        local.effective_kubernetes_minor_version,
        local.istio_minor_version,
        var.compatibility.kubernetes.mode,
        length(local.allowed_kubernetes_minor_versions) > 0 ? join(", ", local.allowed_kubernetes_minor_versions) : "none",
      )
    }
  }
}
