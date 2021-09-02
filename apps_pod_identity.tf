resource "kubernetes_namespace" "aad_pod_identity" {
  metadata {
    name   = "aad-pod-identity"
    labels = local.ns_labels
  }
}

locals {
  aad_pod_identity_config = merge(var.aad_pod_identity.config, {
    "forceNamespaced"               = true,
    "installCRDs"                   = true,
    "mic.leaderElection.namespace"  = kubernetes_namespace.aad_pod_identity.metadata[0].name
    "mic.loggingFormat"             = "json"
    "mic.resources.limits.cpu"      = "500m",
    "mic.resources.limits.memory"   = "512Mi"
    "mic.resources.requests.cpu"    = "100m",
    "mic.resources.requests.memory" = "256Mi",
    "nmi.loggingFormat"             = "json"
    "nmi.micNamespace"              = kubernetes_namespace.aad_pod_identity.metadata[0].name,
    "nmi.resources.limits.cpu"      = "500m",
    "nmi.resources.limits.memory"   = "512Mi"
    "nmi.resources.requests.cpu"    = "100m",
    "nmi.resources.requests.memory" = "256Mi",
    "rbac.allowAccessToSecrets"     = false,
  })
}

resource "helm_release" "aad_pod_identity" {
  name       = "aad-pod-identity"
  repository = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  chart      = "aad-pod-identity"
  version    = "4.1.4"

  namespace = kubernetes_namespace.aad_pod_identity.metadata[0].name

  dynamic "set" {
    for_each = local.aad_pod_identity_config
    content {
      name  = set.key
      value = set.value
    }
  }
}
