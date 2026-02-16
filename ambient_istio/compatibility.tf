locals {
  kubernetes_validation_enabled  = var.kubernetes_compatibility != "skip"
  gateway_api_validation_enabled = var.gateway_api_compatibility != "skip"
}

data "http" "istio_support_status" {
  count = local.kubernetes_validation_enabled ? 1 : 0
  url   = "https://raw.githubusercontent.com/istio/istio.io/master/data/compatibility/supportStatus.yml"

  request_headers = {
    Accept = "application/x-yaml"
  }
}

data "http" "istio_release_args" {
  count = local.gateway_api_validation_enabled ? 1 : 0
  url   = format("https://raw.githubusercontent.com/istio/istio.io/release-%s/data/args.yml", local.istio_minor_version)

  request_headers = {
    Accept = "application/x-yaml"
  }
}

data "kubernetes_resources" "gateway_api_crd" {
  count = local.gateway_api_validation_enabled && var.install_gateway_api_crds == "none" ? 1 : 0

  api_version    = "apiextensions.k8s.io/v1"
  kind           = "CustomResourceDefinition"
  field_selector = "metadata.name=gateways.gateway.networking.k8s.io"
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

  effective_kubernetes_version = trimspace(nonsensitive(var.plugin.cluster_version))

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

  gateway_api_release_args = try(
    yamldecode(data.http.istio_release_args[0].response_body),
    null,
  )

  gateway_api_required_version_raw = var.gateway_api_min_version_override == null ? try(
    trimspace(local.gateway_api_release_args.k8s_gateway_api_version),
    null,
  ) : trimspace(var.gateway_api_min_version_override)

  gateway_api_chart_metadata       = try(yamldecode(file("${path.module}/charts/gateway-api-crds/Chart.yaml")), {})
  gateway_api_vendored_version_raw = try(trimspace(tostring(local.gateway_api_chart_metadata.appVersion)), null)

  gateway_api_crd_object = try(data.kubernetes_resources.gateway_api_crd[0].objects[0], null)
  gateway_api_unmanaged_bundle_version_raw = try(
    trimspace(tostring(local.gateway_api_crd_object.metadata.annotations["gateway.networking.k8s.io/bundle-version"])),
    null,
  )

  gateway_api_installed_version_raw = var.install_gateway_api_crds == "none" ? local.gateway_api_unmanaged_bundle_version_raw : local.gateway_api_vendored_version_raw

  gateway_api_required_version_normalized  = local.gateway_api_required_version_raw == null ? null : trimprefix(lower(local.gateway_api_required_version_raw), "v")
  gateway_api_installed_version_normalized = local.gateway_api_installed_version_raw == null ? null : trimprefix(lower(local.gateway_api_installed_version_raw), "v")

  gateway_api_required_version_is_valid = local.gateway_api_required_version_normalized != null && can(
    regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", local.gateway_api_required_version_normalized)
  )
  gateway_api_installed_version_is_valid = local.gateway_api_installed_version_normalized != null && can(
    regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", local.gateway_api_installed_version_normalized)
  )

  gateway_api_required_version_parts  = local.gateway_api_required_version_is_valid ? split(".", local.gateway_api_required_version_normalized) : []
  gateway_api_installed_version_parts = local.gateway_api_installed_version_is_valid ? split(".", local.gateway_api_installed_version_normalized) : []

  gateway_api_required_version_tuple = local.gateway_api_required_version_is_valid ? [
    tonumber(local.gateway_api_required_version_parts[0]),
    tonumber(local.gateway_api_required_version_parts[1]),
    tonumber(local.gateway_api_required_version_parts[2]),
  ] : null
  gateway_api_installed_version_tuple = local.gateway_api_installed_version_is_valid ? [
    tonumber(local.gateway_api_installed_version_parts[0]),
    tonumber(local.gateway_api_installed_version_parts[1]),
    tonumber(local.gateway_api_installed_version_parts[2]),
  ] : null

  gateway_api_installed_meets_required = local.gateway_api_required_version_tuple != null && local.gateway_api_installed_version_tuple != null && (
    local.gateway_api_installed_version_tuple[0] > local.gateway_api_required_version_tuple[0] || (
      local.gateway_api_installed_version_tuple[0] == local.gateway_api_required_version_tuple[0] && (
        local.gateway_api_installed_version_tuple[1] > local.gateway_api_required_version_tuple[1] || (
          local.gateway_api_installed_version_tuple[1] == local.gateway_api_required_version_tuple[1] &&
          local.gateway_api_installed_version_tuple[2] >= local.gateway_api_required_version_tuple[2]
        )
      )
    )
  )
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

resource "terraform_data" "gateway_api_compatibility_guard" {
  count = local.gateway_api_validation_enabled ? 1 : 0

  input = {
    istio_version                    = var.istio_version
    istio_minor_version              = local.istio_minor_version
    install_gateway_api_crds         = var.install_gateway_api_crds
    gateway_api_compatibility        = var.gateway_api_compatibility
    gateway_api_min_version_override = var.gateway_api_min_version_override
  }

  lifecycle {
    precondition {
      condition     = local.gateway_api_required_version_raw != null
      error_message = "Could not determine required Gateway API version from Istio release args. Set gateway_api_min_version_override or use gateway_api_compatibility=\"skip\"."
    }

    precondition {
      condition     = local.gateway_api_required_version_is_valid
      error_message = format("Required Gateway API version '%s' is not a valid semantic version.", local.gateway_api_required_version_raw)
    }

    precondition {
      condition     = var.install_gateway_api_crds != "none" || local.gateway_api_crd_object != null
      error_message = "install_gateway_api_crds is set to \"none\" but gateways.gateway.networking.k8s.io CRD was not found in the cluster. Install Gateway API CRDs or use gateway_api_compatibility=\"skip\"."
    }

    precondition {
      condition     = local.gateway_api_installed_version_raw != null
      error_message = "Gateway API installed version could not be determined. For unmanaged CRDs, ensure gateways.gateway.networking.k8s.io has annotation gateway.networking.k8s.io/bundle-version."
    }

    precondition {
      condition     = local.gateway_api_installed_version_is_valid
      error_message = format("Installed Gateway API version '%s' is not a valid semantic version.", local.gateway_api_installed_version_raw)
    }

    precondition {
      condition = local.gateway_api_installed_meets_required
      error_message = var.install_gateway_api_crds == "none" ? format(
        "Gateway API CRDs in the cluster are too old. Installed: %s, required: %s for Istio %s. Upgrade CRDs in the cluster or use gateway_api_compatibility=\"skip\".",
        local.gateway_api_installed_version_raw,
        local.gateway_api_required_version_raw,
        local.istio_minor_version,
        ) : format(
        "Vendored gateway-api-crds chart is too old. Installed (chart appVersion): %s, required: %s for Istio %s. Update charts/gateway-api-crds/Chart.yaml (version + appVersion) and charts/gateway-api-crds/templates/standard-install.yaml, or use gateway_api_compatibility=\"skip\".",
        local.gateway_api_installed_version_raw,
        local.gateway_api_required_version_raw,
        local.istio_minor_version,
      )
    }
  }
}
