data "http" "istio_release_args" {
  count = local.gateway_api_args_fetch_enabled ? 1 : 0
  url   = local.istio_release_args_url

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
  istio_release_args_http_status = try(data.http.istio_release_args[0].status_code, null)

  gateway_api_required_version_raw = var.gateway_api_min_version_override != null ? trimspace(var.gateway_api_min_version_override) : try(
    trimspace(yamldecode(data.http.istio_release_args[0].response_body).k8s_gateway_api_version),
    null,
  )

  gateway_api_vendored_version_raw = try(
    trimspace(tostring(yamldecode(file("${path.module}/charts/gateway-api-crds/Chart.yaml")).appVersion)),
    null,
  )

  gateway_api_crd_object = try(data.kubernetes_resources.gateway_api_crd[0].objects[0], null)
  gateway_api_unmanaged_bundle_version_raw = try(
    trimspace(tostring(local.gateway_api_crd_object.metadata.annotations["gateway.networking.k8s.io/bundle-version"])),
    null,
  )
  gateway_api_installed_version_raw = var.install_gateway_api_crds == "none" ? local.gateway_api_unmanaged_bundle_version_raw : local.gateway_api_vendored_version_raw

  gateway_api_semver_pattern = "^[0-9]+\\.[0-9]+\\.[0-9]+$"

  gateway_api_required_version_normalized  = local.gateway_api_required_version_raw == null ? null : trimprefix(lower(local.gateway_api_required_version_raw), "v")
  gateway_api_installed_version_normalized = local.gateway_api_installed_version_raw == null ? null : trimprefix(lower(local.gateway_api_installed_version_raw), "v")

  gateway_api_required_version_parts = local.gateway_api_required_version_normalized != null && can(
    regex(local.gateway_api_semver_pattern, local.gateway_api_required_version_normalized)
  ) ? split(".", local.gateway_api_required_version_normalized) : null
  gateway_api_installed_version_parts = local.gateway_api_installed_version_normalized != null && can(
    regex(local.gateway_api_semver_pattern, local.gateway_api_installed_version_normalized)
  ) ? split(".", local.gateway_api_installed_version_normalized) : null

  gateway_api_required_version_tuple = local.gateway_api_required_version_parts == null ? null : [
    for part in local.gateway_api_required_version_parts : tonumber(part)
  ]
  gateway_api_installed_version_tuple = local.gateway_api_installed_version_parts == null ? null : [
    for part in local.gateway_api_installed_version_parts : tonumber(part)
  ]

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

resource "terraform_data" "gateway_api_compatibility_guard" {
  count = local.gateway_api_validation_enabled ? 1 : 0

  input = {
    istio_version                    = local.istio_chart_version
    istio_minor_version              = local.istio_minor_version
    install_gateway_api_crds         = var.install_gateway_api_crds
    gateway_api_compatibility        = var.gateway_api_compatibility
    gateway_api_min_version_override = var.gateway_api_min_version_override
  }

  lifecycle {
    precondition {
      condition = !local.gateway_api_args_fetch_enabled || local.istio_release_args_http_status == 200
      error_message = format(
        "Failed to fetch Istio release args for Istio minor %s from %s (HTTP status: %s). Set gateway_api_min_version_override or use gateway_api_compatibility=\"skip\".",
        local.istio_minor_version,
        local.istio_release_args_url,
        local.istio_release_args_http_status == null ? "unknown" : tostring(local.istio_release_args_http_status),
      )
    }

    precondition {
      condition = local.gateway_api_required_version_raw != null
      error_message = format(
        "Could not determine required Gateway API version for Istio minor %s. Expected args URL: %s. Set gateway_api_min_version_override or use gateway_api_compatibility=\"skip\".",
        local.istio_minor_version,
        local.istio_release_args_url,
      )
    }

    precondition {
      condition     = local.gateway_api_required_version_parts != null
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
      condition     = local.gateway_api_installed_version_parts != null
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
