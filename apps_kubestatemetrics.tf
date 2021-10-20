resource "kubernetes_namespace" "kube_state_metrics" {
  count = var.deploy_kube_state_metrics ? 1 : 0

  metadata {
    name   = "kube-state-metrics"
    labels = local.ns_labels
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
  version    = "2.1.12"

  namespace = kubernetes_namespace.kube_state_metrics[0].metadata[0].name

  dynamic "set" {
    for_each = local.kube_state_metrics_config
    content {
      name  = set.key
      value = set.value
    }
  }
}
