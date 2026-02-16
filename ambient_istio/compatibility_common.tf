locals {
  kubernetes_validation_enabled  = var.kubernetes_compatibility != "skip"
  gateway_api_validation_enabled = var.gateway_api_compatibility != "skip"

  # Normalize user input once and reuse it everywhere.
  istio_chart_version = trimprefix(trimspace(var.istio_version), "v")
  istio_version_parts = split(".", local.istio_chart_version)
  istio_minor_version = format(
    "%d.%d",
    tonumber(local.istio_version_parts[0]),
    tonumber(local.istio_version_parts[1]),
  )
  istio_release_args_url = format(
    "https://raw.githubusercontent.com/istio/istio.io/release-%s/data/args.yml",
    local.istio_minor_version,
  )

  effective_kubernetes_version = trimspace(nonsensitive(var.plugin.cluster_version))
  effective_kubernetes_parts   = split(".", trimprefix(local.effective_kubernetes_version, "v"))
  effective_kubernetes_minor_version = format(
    "%d.%d",
    tonumber(local.effective_kubernetes_parts[0]),
    tonumber(local.effective_kubernetes_parts[1]),
  )

  gateway_api_args_fetch_enabled = local.gateway_api_validation_enabled && var.gateway_api_min_version_override == null
}
