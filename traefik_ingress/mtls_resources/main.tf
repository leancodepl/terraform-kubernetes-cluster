# =============================================================================
# mTLS Resources Submodule - Main
# =============================================================================
# Creates mTLS resources for Traefik to use when connecting to backends.
# =============================================================================

# -----------------------------------------------------------------------------
# Client Certificate
# -----------------------------------------------------------------------------
# This certificate is presented by Traefik when connecting to mTLS-enabled
# backends. It's signed by the internal CA ClusterIssuer.
# -----------------------------------------------------------------------------
resource "kubernetes_manifest" "client_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "${var.service_name}-client-cert"
      namespace = var.namespace
      labels    = var.labels
    }
    spec = {
      secretName  = "${var.service_name}-client-cert"
      duration    = var.certificate_duration
      renewBefore = var.certificate_renew_before
      privateKey = {
        algorithm = "ECDSA"
        size      = 256
      }
      commonName = "${var.service_name}.${var.namespace}.svc.cluster.local"
      dnsNames = [
        var.service_name,
        "${var.service_name}.${var.namespace}",
        "${var.service_name}.${var.namespace}.svc",
        "${var.service_name}.${var.namespace}.svc.cluster.local"
      ]
      issuerRef = {
        name  = var.mtls_config.issuer_name
        kind  = var.mtls_config.issuer_kind
        group = var.mtls_config.issuer_group
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Copy Root CA Secret to target namespace
# -----------------------------------------------------------------------------
# Traefik's ServersTransport requires a Secret (not ConfigMap) for CA certs.
# We copy the Root CA from cert-manager namespace to the target namespace.
# -----------------------------------------------------------------------------
data "kubernetes_secret_v1" "root_ca" {
  metadata {
    name      = var.mtls_config.root_ca_secret_name
    namespace = var.mtls_config.ca_secret_namespace
  }
}

resource "kubernetes_secret_v1" "ca_bundle" {
  metadata {
    name      = "internal-ca-bundle"
    namespace = var.namespace
    labels    = var.labels
  }

  data = {
    "ca.crt" = data.kubernetes_secret_v1.root_ca.data["ca.crt"]
  }

  type = "Opaque"
}
