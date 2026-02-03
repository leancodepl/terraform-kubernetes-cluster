# =============================================================================
# Traefik mTLS Configuration
# =============================================================================
# This file creates mTLS-specific resources when mtls_enabled is true:
# - Traefik client certificate for presenting to backends
# - CA bundle Secret for verifying backend server certificates
#
# The ServersTransport CRD is created via the traefik-options Helm chart
# to avoid kubernetes_manifest CRD timing issues.
# =============================================================================

# -----------------------------------------------------------------------------
# mTLS Resources Submodule
# -----------------------------------------------------------------------------
# Encapsulates the client certificate and CA bundle creation for reuse.
# This allows tests to use the same production code.
# -----------------------------------------------------------------------------
module "mtls_resources" {
  source = "./mtls_resources"
  count  = local.mtls_enabled ? 1 : 0

  mtls_config  = var.mtls_config
  namespace    = kubernetes_namespace_v1.traefik.metadata[0].name
  service_name = "traefik"
  labels = merge(local.ns_labels, {
    "app.kubernetes.io/component" = "mtls"
  })

  depends_on = [helm_release.traefik]
}

locals {
  traefik_options_mtls = local.mtls_enabled ? {
    enabled              = true
    caBundleSecretName   = module.mtls_resources[0].ca_bundle_secret_name
    clientCertSecretName = module.mtls_resources[0].client_cert_secret_name
  } : {}
}
