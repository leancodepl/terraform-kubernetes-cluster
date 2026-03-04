output "plugin" {
  description = "The output of this plugin to be passed to follow-up plugins."
  value = {
    namespace_name = kubernetes_namespace_v1.main.metadata[0].name
  }
}

output "helm" {
  description = <<-EOT
    Helm chart configuration produced by this module, keyed by release name.
    Parameters are key/value pairs for use with Helm --set flags.
  EOT
  value = {
    (local.datadog_release.name) = {
      namespace  = kubernetes_namespace_v1.main.metadata[0].name
      repository = local.datadog_release.repository
      chart      = local.datadog_release.chart
      version    = local.datadog_release.version
      parameters = local.datadog_parameters
      values     = local.datadog_values
    }
  }
}
