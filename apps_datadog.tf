resource "kubernetes_namespace" "datadog" {
  metadata {
    name   = "datadog"
    labels = local.ns_labels
  }
}

locals {
  datadog_config = merge(var.datadog.config, {
    "datadog.kubeStateMetricsEnabled" = false,

    # FIXME: https://github.com/DataDog/integrations-core/issues/2582
    # And the hack with custom CA file does not work for AKS v1.19 and up
    "datadog.kubelet.tlsVerify" = false,
  })
}

# See: https://github.com/DataDog/helm-charts/tree/master/charts/datadog
resource "helm_release" "datadog_agent" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = "2.19.6"

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
