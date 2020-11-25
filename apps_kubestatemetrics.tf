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

resource "helm_release" "kube_state_metrics" {
  count = var.deploy_kube_state_metrics ? 1 : 0

  name       = "kube-state-metrics"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kube-state-metrics"
  version    = "1.0.0"

  namespace = kubernetes_manifest.kube_state_metrics_ns[0].object.metadata.name

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "resources.requests.memory"
    value = "200Mi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }
  set {
    name  = "resources.limits.memory"
    value = "300Mi"
  }
}
