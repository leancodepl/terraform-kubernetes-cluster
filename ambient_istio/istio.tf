locals {
  istio_repository = "https://istio-release.storage.googleapis.com/charts"

  istiod_resources = {
    "pilot.resources.requests.cpu"    = var.istiod_resources.requests.cpu
    "pilot.resources.requests.memory" = var.istiod_resources.requests.memory
    "pilot.resources.limits.cpu"      = var.istiod_resources.limits.cpu
    "pilot.resources.limits.memory"   = var.istiod_resources.limits.memory
  }

  ztunnel_resources = {
    "resources.requests.cpu"    = var.ztunnel_resources.requests.cpu
    "resources.requests.memory" = var.ztunnel_resources.requests.memory
    "resources.limits.cpu"      = var.ztunnel_resources.limits.cpu
    "resources.limits.memory"   = var.ztunnel_resources.limits.memory
  }

  istio_base_config = var.istio_config.base

  istiod_config = merge(local.istiod_resources, {
    "profile" = "ambient"
  }, var.istio_config.istiod)

  cni_config = merge({
    "profile" = "ambient"
  }, var.istio_config.cni)

  ztunnel_config = merge(local.ztunnel_resources, var.istio_config.ztunnel)
}

resource "kubernetes_namespace_v1" "istio_system" {
  metadata {
    name = "istio-system"
    labels = merge(local.ns_labels, {
      env = var.plugin.prefix
    })
  }
}

# Istio CRDs and cluster-wide RBAC roles.
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = local.istio_repository
  chart      = "base"
  version    = var.istio_version

  namespace = kubernetes_namespace_v1.istio_system.metadata[0].name

  set = [
    for k, v in local.istio_base_config : {
      name  = k
      value = v
    }
  ]
}

# Istio control plane (discovery service) in ambient mode.
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = local.istio_repository
  chart      = "istiod"
  version    = var.istio_version

  namespace = kubernetes_namespace_v1.istio_system.metadata[0].name

  set = [
    for k, v in local.istiod_config : {
      name  = k
      value = v
    }
  ]

  depends_on = [
    helm_release.istio_base,
    helm_release.gateway_api_crds,
  ]
}

# CNI node agent that configures pod networking for the ambient mesh.
resource "helm_release" "istio_cni" {
  name       = "istio-cni"
  repository = local.istio_repository
  chart      = "cni"
  version    = var.istio_version

  namespace = kubernetes_namespace_v1.istio_system.metadata[0].name

  set = [
    for k, v in local.cni_config : {
      name  = k
      value = v
    }
  ]

  depends_on = [helm_release.istiod]
}

# Per-node proxy (DaemonSet) that handles L4 mTLS between pods.
resource "helm_release" "ztunnel" {
  name       = "ztunnel"
  repository = local.istio_repository
  chart      = "ztunnel"
  version    = var.istio_version

  namespace = kubernetes_namespace_v1.istio_system.metadata[0].name

  set = [
    for k, v in local.ztunnel_config : {
      name  = k
      value = v
    }
  ]

  depends_on = [helm_release.istio_cni]
}
