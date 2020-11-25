locals {
  terraform_excluded_fields = ["datadog.apiKey", "datadog.kubeStateMetricsEnabled"]
}

# See: https://github.com/DataDog/helm-charts/tree/master/charts/datadog
resource "helm_release" "datadog_agent" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = "2.6.0"
  namespace  = "datadog"

  set {
    name  = "datadog.apiKey"
    value = var.datadog.secret
  }
  set {
    name  = "datadog.kubeStateMetricsEnabled"
    value = false
  }
  dynamic "set" {
    for_each = { for k, v in var.datadog.config : k => v if ! contains(local.terraform_excluded_fields, k) }
    content {
      name  = set.key
      value = set.value
    }
  }
}
