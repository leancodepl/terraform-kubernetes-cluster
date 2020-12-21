resource "kubernetes_manifest" "aad_pod_identity_ns" {
  count = var.deploy_aad_pod_identity ? 1 : 0

  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name   = "aad-pod-identity"
      labels = local.ns_labels
    }
  }
}

locals {
  aad_pod_identity_config = merge(var.aad_pod_identity.config, {
    "forceNamespaced"               = true,
    "installCRDs"                   = true,
    "mic.leaderElection.namespace"  = var.deploy_aad_pod_identity ? kubernetes_manifest.aad_pod_identity_ns[0].object.metadata.name : "default",
    "mic.loggingFormat"             = "json"
    "mic.resources.limits.cpu"      = "500m",
    "mic.resources.limits.memory"   = "512Mi"
    "mic.resources.requests.cpu"    = "100m",
    "mic.resources.requests.memory" = "256Mi",
    "nmi.loggingFormat"             = "json"
    "nmi.micNamespace"              = var.deploy_aad_pod_identity ? kubernetes_manifest.aad_pod_identity_ns[0].object.metadata.name : "default",
    "nmi.resources.limits.cpu"      = "500m",
    "nmi.resources.limits.memory"   = "512Mi"
    "nmi.resources.requests.cpu"    = "100m",
    "nmi.resources.requests.memory" = "256Mi",
    "rbac.allowAccessToSecrets"     = false,
  })
}

resource "helm_release" "aad_pod_identity" {
  count = var.deploy_aad_pod_identity ? 1 : 0

  name       = "aad-pod-identity"
  repository = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  chart      = "aad-pod-identity"
  version    = "2.0.3"

  namespace = kubernetes_manifest.aad_pod_identity_ns[0].object.metadata.name

  dynamic "set" {
    for_each = local.aad_pod_identity_config
    content {
      name  = set.key
      value = set.value
    }
  }
}
