locals {
  aad_pod_identity_resources = {
    "mic.resources.limits.cpu"      = var.resources.mic.limits.cpu,
    "mic.resources.limits.memory"   = var.resources.mic.limits.memory,
    "mic.resources.requests.cpu"    = var.resources.mic.requests.cpu,
    "mic.resources.requests.memory" = var.resources.mic.requests.memory,

    "nmi.resources.limits.cpu"      = var.resources.nmi.limits.cpu,
    "nmi.resources.limits.memory"   = var.resources.nmi.limits.memory,
    "nmi.resources.requests.cpu"    = var.resources.nmi.requests.cpu,
    "nmi.resources.requests.memory" = var.resources.nmi.requests.memory,
  }
  aad_pod_identity_aks = {
    "forceNamespaced"           = true,
    "installCRDs"               = true,
    "rbac.allowAccessToSecrets" = false,

    "mic.loggingFormat"            = "json"
    "mic.leaderElection.namespace" = kubernetes_namespace.aad_pod_identity.metadata[0].name

    "nmi.loggingFormat" = "json"
    "nmi.micNamespace"  = kubernetes_namespace.aad_pod_identity.metadata[0].name,
  }
  aad_pod_identity_config = merge(local.aad_pod_identity_resources, var.config, local.aad_pod_identity_aks)
}

resource "kubernetes_namespace" "aad_pod_identity" {
  metadata {
    name   = "aad-pod-identity"
    labels = local.ns_labels
  }
}

resource "helm_release" "aad_pod_identity" {
  name       = "aad-pod-identity"
  repository = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  chart      = "aad-pod-identity"
  version    = "4.1.9"

  namespace = kubernetes_namespace.aad_pod_identity.metadata[0].name

  dynamic "set" {
    for_each = local.aad_pod_identity_config
    content {
      name  = set.key
      value = set.value
    }
  }
}
