resource "kubernetes_manifest" "datadog_ns" {
  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "datadog"
    }
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
  version    = "2.6.0"

  namespace = kubernetes_manifest.datadog_ns.object.metadata.name

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
