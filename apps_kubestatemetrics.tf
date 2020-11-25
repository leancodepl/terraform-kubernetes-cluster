resource "kubernetes_namespace" "kube_state_metrics" {
  count = var.deploy_kube_state_metrics ? 1 : 0

  metadata {
    name = "kube-state-metrics"
  }
}

resource "helm_release" "kube_state_metrics" {
  count = var.deploy_kube_state_metrics ? 1 : 0

  name       = "kube-state-metrics"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kube-state-metrics"
  version    = "1.0.0"

  namespace = kubernetes_namespace.kube_state_metrics[0].metadata[0].name

  set {
    name = "resources"
    value = {
      requests = {
        cpu    = "10m"
        memory = "10Mi"
      }
      limits = {
        cpu    = "10m"
        memory = "10Mi"
      }
    }
  }
  set {
    name   = "sources"
    values = ["service", "ingress"]
  }
  set {
    name  = "provider"
    value = "azure"
  }
  set {
    name  = "registry"
    value = "txt"
  }
  set {
    name  = "txtOwnerId"
    value = "external-dns-${var.prefix}-k8s"
  }
  set {
    name  = "azure.useManagedIdentityExtension"
    value = true
  }
}
