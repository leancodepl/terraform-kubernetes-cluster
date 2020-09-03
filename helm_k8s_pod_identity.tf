resource "helm_release" "aad_pod_identity" {
  count = var.deploy_aad_pod_identity ? 1 : 0

  name       = "aad-pod-identity"
  repository = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  chart      = "aad-pod-identity"
  version    = "2.0.1"

  set {
    name  = "forceNameSpaced"
    value = true
  }

  set {
    name  = "mic.tag"
    value = "1.6.2"
  }

  set {
    name  = "nmi.tag"
    value = "1.6.2"
  }

  set {
    name  = "installCRDs"
    value = true
  }

  set {
    name  = "rbac.allowAccessToSecrets"
    value = false
  }

}
