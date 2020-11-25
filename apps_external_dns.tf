resource "kubernetes_manifest" "external_dns_ns" {
  count = var.deploy_external_dns ? 1 : 0

  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "external-dns"
    }
  }
}

resource "helm_release" "external_dns" {
  count = var.deploy_external_dns ? 1 : 0

  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "4.0.0"

  namespace = kubernetes_manifest.external_dns_ns[0].object.metadata.name


  set {
    name  = "resources.requests.cpu"
    value = "10m"
  }
  set {
    name  = "resources.requests.memory"
    value = "10Mi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "10m"
  }
  set {
    name  = "resources.limits.memory"
    value = "10Mi"
  }
  set {
    name  = "sources[0]"
    value = "service"
  }
  set {
    name  = "sources[1]"
    value = "ingress"
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
