locals {
  kubernetes_validation_enabled  = var.compatibility.kubernetes.mode != "skip"
  gateway_api_validation_enabled = var.compatibility.gateway_api.mode != "skip"

  # Normalize user input once and reuse it everywhere.
  istio_chart_version     = trimprefix(trimspace(var.istio_version), "v")
  istio_major_minor_parts = regex("^(\\d+)\\.(\\d+)", local.istio_chart_version)
  istio_minor_version = format(
    "%d.%d",
    tonumber(local.istio_major_minor_parts[0]),
    tonumber(local.istio_major_minor_parts[1]),
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

  gateway_api_args_fetch_enabled = local.gateway_api_validation_enabled && var.compatibility.gateway_api.min_version_override == null
}
