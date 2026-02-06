locals {
  istio_repository = "https://istio-release.storage.googleapis.com/charts"

  istio_base_config = {}

  istiod_resources = {
    "pilot.resources.requests.cpu"    = var.istiod_resources.requests.cpu
    "pilot.resources.requests.memory" = var.istiod_resources.requests.memory
    "pilot.resources.limits.cpu"      = var.istiod_resources.limits.cpu
    "pilot.resources.limits.memory"   = var.istiod_resources.limits.memory
  }

  istiod_config = merge(local.istiod_resources, {
    "profile" = "ambient"
  })

  cni_config = {
    "profile" = "ambient"
  }

  ztunnel_resources = {
    "resources.requests.cpu"    = var.ztunnel_resources.requests.cpu
    "resources.requests.memory" = var.ztunnel_resources.requests.memory
    "resources.limits.cpu"      = var.ztunnel_resources.limits.cpu
    "resources.limits.memory"   = var.ztunnel_resources.limits.memory
  }

  ztunnel_config = local.ztunnel_resources
}

locals {
  istio_config = merge(local.istio_base_config, var.istio_config)
}

resource "kubernetes_namespace_v1" "istio_system" {
  metadata {
    name = "istio-system"
    labels = merge(local.ns_labels, {
      env = var.plugin.prefix
    })
  }
}

resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = local.istio_repository
  chart      = "base"
  version    = var.istio_version

  namespace = kubernetes_namespace_v1.istio_system.metadata[0].name

  set = [
    for k, v in local.istio_config : {
      name  = k
      value = v
    }
  ]
}

resource "helm_release" "gateway_api_crds" {
  count = var.install_gateway_api_crds ? 1 : 0

  name      = "gateway-api-crds"
  namespace = kubernetes_namespace_v1.istio_system.metadata[0].name
  chart     = "${path.module}/charts/gateway-api-crds"

  depends_on = [helm_release.istio_base]
}

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
