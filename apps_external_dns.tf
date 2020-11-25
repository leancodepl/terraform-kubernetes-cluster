resource "kubernetes_namespace" "external_dns" {
  count = var.deploy_external_dns ? 1 : 0

  metadata {
    name = "external-dns"
  }
}

resource "helm_release" "external_dns" {
  count = var.deploy_external_dns ? 1 : 0

  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "4.0.0"

  namespace = kubernetes_namespace.external_dns[0].metadata[0].name

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
