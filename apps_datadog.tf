resource "kubernetes_namespace" "datadog" {
  metadata {
    name   = "datadog"
    labels = local.ns_labels
  }
}

locals {
  datadog_config = merge(var.datadog.config, {
    "datadog.kubeStateMetricsEnabled" = false,
  })
}

# See: https://github.com/DataDog/helm-charts/tree/master/charts/datadog
resource "helm_release" "datadog_agent" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = "2.6.7"

  namespace = kubernetes_namespace.datadog.metadata[0].name

  set_sensitive {
    name  = "datadog.apiKey"
    value = var.datadog.secret
  }
  dynamic "set" {
    for_each = local.datadog_config
    content {
      name  = set.key
      value = set.value
    }
  }
}
