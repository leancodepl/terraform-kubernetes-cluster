# Kubernetes Gateway API CRDs (standard channel). Required for Istio waypoint proxies (L7).
# See charts/gateway-api-crds/Chart.yaml for version info and update instructions.
#
# Version compatibility: Istio 1.28 targets Gateway API v1.4.x. The Standard channel
# is backwards-compatible -- upgrading CRDs is additive and safe for existing resources.
#
# AKS note: AKS offers managed Gateway API CRDs (preview), currently v1.2.1/v1.3.0,
# but those are still too low for istio.
# https://learn.microsoft.com/en-us/azure/aks/managed-gateway-api
resource "helm_release" "gateway_api_crds" {
  count = var.install_gateway_api_crds ? 1 : 0

  name      = "gateway-api-crds"
  namespace = kubernetes_namespace_v1.istio_system.metadata[0].name
  chart     = "${path.module}/charts/gateway-api-crds"
}
