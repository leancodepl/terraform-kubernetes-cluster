locals {
  aad_pod_identity_excluded_fields = []
}

resource "kubernetes_manifest" "aad_pod_identity_ns" {
  count = var.deploy_aad_pod_identity ? 1 : 0

  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "aad-pod-identity"
    }
  }
}

resource "helm_release" "aad_pod_identity" {
  count = var.deploy_aad_pod_identity ? 1 : 0

  name       = "aad-pod-identity"
  repository = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  chart      = "aad-pod-identity"
  version    = "2.0.3"

  namespace = kubernetes_manifest.aad_pod_identity_ns[0].object.metadata.name

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
    value = kubernetes_manifest.aad_pod_identity_ns[0].object.metadata.name
  }
  set {
    name  = "nmi.micNamespace"
    value = kubernetes_manifest.aad_pod_identity_ns[0].object.metadata.name
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
  set {
    name  = "mic.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "mic.resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "mic.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "mic.resources.limits.memory"
    value = "512Mi"
  }
  set {
    name  = "nmi.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "nmi.resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "nmi.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "nmi.resources.limits.memory"
    value = "512Mi"
  }

  dynamic "set" {
    for_each = { for k, v in var.aad_pod_identity.config : k => v if ! contains(local.aad_pod_identity_excluded_fields, k) }
    content {
      name  = set.key
      value = set.value
    }
  }
}
