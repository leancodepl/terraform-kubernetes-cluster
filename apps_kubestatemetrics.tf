resource "kubernetes_manifest" "kube_state_metrics_ns" {
  count = var.deploy_kube_state_metrics ? 1 : 0

  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "kube-state-metrics"
    }
  }
}

locals {
  kube_state_metrics_config = {
    "resources.limits.cpu"      = "200m",
    "resources.limits.memory"   = "300Mi",
    "resources.requests.cpu"    = "100m",
    "resources.requests.memory" = "200Mi",
  }
}

resource "helm_release" "kube_state_metrics" {
  count = var.deploy_kube_state_metrics ? 1 : 0

  name       = "kube-state-metrics"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kube-state-metrics"
  version    = "1.0.0"

  namespace = kubernetes_manifest.kube_state_metrics_ns[0].object.metadata.name

  dynamic "set" {
    for_each = local.kube_state_metrics_config
    content {
      name  = set.key
      value = set.value
    }
  }
}
