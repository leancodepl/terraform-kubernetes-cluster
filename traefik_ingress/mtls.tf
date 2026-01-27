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
# Traefik Client Certificate
# -----------------------------------------------------------------------------
# This certificate is used by Traefik when connecting to mTLS-enabled backends.
# It's created using the internal CA ClusterIssuer from the mtls module.
# -----------------------------------------------------------------------------
resource "kubernetes_manifest" "traefik_client_cert" {
  count = local.mtls_enabled ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "traefik-client-cert"
      namespace = kubernetes_namespace_v1.traefik.metadata[0].name
      labels = merge(local.ns_labels, {
        "app.kubernetes.io/component" = "mtls"
      })
    }
    spec = {
      secretName  = "traefik-client-cert"
      duration    = "24h"
      renewBefore = "1h"
      privateKey = {
        algorithm = "ECDSA"
        size      = 256
      }
      commonName = "traefik.traefik.svc.cluster.local"
      dnsNames = [
        "traefik",
        "traefik.traefik",
        "traefik.traefik.svc",
        "traefik.traefik.svc.cluster.local"
      ]
      issuerRef = {
        name  = var.mtls_config.issuer_name
        kind  = var.mtls_config.issuer_kind
        group = var.mtls_config.issuer_group
      }
    }
  }

  depends_on = [helm_release.traefik]
}

# -----------------------------------------------------------------------------
# Copy Root CA Secret to traefik namespace
# -----------------------------------------------------------------------------
# We copy the Root CA certificate from cert-manager namespace to traefik namespace.
# This is more reliable than depending on trust-manager's async ConfigMap sync.
# Traefik's ServersTransport requires a Secret (not ConfigMap) for CA certificates.
# -----------------------------------------------------------------------------
data "kubernetes_secret_v1" "root_ca" {
  count = local.mtls_enabled ? 1 : 0

  metadata {
    name      = var.mtls_config.root_ca_secret_name
    namespace = var.mtls_config.ca_secret_namespace
  }
}

resource "kubernetes_secret_v1" "internal_ca_bundle" {
  count = local.mtls_enabled ? 1 : 0

  metadata {
    name      = "internal-ca-bundle"
    namespace = kubernetes_namespace_v1.traefik.metadata[0].name
    labels = merge(local.ns_labels, {
      "app.kubernetes.io/component" = "mtls"
    })
  }

  data = {
    "ca.crt" = data.kubernetes_secret_v1.root_ca[0].data["ca.crt"]
  }

  type = "Opaque"
}
