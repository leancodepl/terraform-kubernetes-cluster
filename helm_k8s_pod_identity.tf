resource "kubernetes_namespace" "aad_pod_identity" {
  metadata {
    name = "aad-pod-identity"
  }
}

resource "helm_release" "aad_pod_identity" {
  count = var.deploy_aad_pod_identity ? 1 : 0

  name       = "aad-pod-identity"
  namespace  = kubernetes.kubernetes_namespace.aad_pod_identity.metadata[0].name
  repository = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  chart      = "aad-pod-identity"
  version    = "2.0.1"

  set {
    name  = "mic.tag"
    value = "1.6.2"
  }

  set {
    name  = "mic.leaderElection.namespace"
    value = kubernetes.kubernetes_namespace.aad_pod_identity.metadata[0].name
  }

  set {
    name  = "nmi.tag"
    value = "1.6.2"
  }

  set {
    name  = "nmi.micNamespace"
    value = kubernetes.kubernetes_namespace.aad_pod_identity.metadata[0].name
  }

  set {
    name  = "installCRDs"
    value = true
  }

  set {
    name  = "rbac.allowAccessToSecrets"
    value = false
  }

  set {
    name  = "forceNameSpaced"
    value = true
  }
}
