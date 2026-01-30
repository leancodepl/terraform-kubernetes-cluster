# =============================================================================
# trust-manager
# =============================================================================
# trust-manager distributes CA certificates across namespaces via Bundle resources.
# It watches Bundle CRs and creates ConfigMaps containing the CA bundle in
# namespaces that match the namespace selector.
#
# The Bundle resource targets namespaces with the label:
#   mtls.leancode.pl/enabled: "true"
# =============================================================================

resource "helm_release" "trust_manager" {
  name       = "trust-manager"
  repository = "https://charts.jetstack.io"
  chart      = "trust-manager"
  version    = var.helm_versions.trust_manager
  namespace  = local.cert_manager_ns

  set = [
    # trust-manager needs to read Secrets from its own namespace
    {
      name  = "app.trust.namespace"
      value = local.cert_manager_ns
    },
    # Enable leader election for HA deployments
    {
      name  = "app.leaderElection.enabled"
      value = "true"
    },
    # Metrics for monitoring
    {
      name  = "app.metrics.service.enabled"
      value = "true"
    }
  ]

  depends_on = [helm_release.cert_manager_csi_driver]
}
