resource "kubernetes_namespace" "aad_pod_identity" {
  count = var.deploy_aad_pod_identity ? 1 : 0

  metadata {
    name = "aad-pod-identity"
  }
}

resource "helm_release" "aad_pod_identity" {
  count = var.deploy_aad_pod_identity ? 1 : 0

  name       = "aad-pod-identity"
  repository = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  chart      = "aad-pod-identity"
  version    = "2.0.3"

  namespace = kubernetes_namespace.aad_pod_identity[0].metadata[0].name

  set {
    name  = "mic.tag"
    value = "1.7.0"
  }

  set {
    name  = "nmi.tag"
    value = "1.7.0"
  }

  set {
    name  = "mic.loggingFormat"
    value = "json"
  }

  set {
    name  = "mic.leaderElection.namespace"
    value = kubernetes.kubernetes_namespace.aad_pod_identity.metadata[0].name
  }

  set {
    name  = "mic.resources"
    value = var.aad_pod_identity.mic.resources
  }

  set {
    name  = "nmi.micNamespace"
    value = kubernetes.kubernetes_namespace.aad_pod_identity.metadata[0].name
  }

  set {
    name  = "nmi.resources"
    value = var.aad_pod_identity.nmi.resources
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
