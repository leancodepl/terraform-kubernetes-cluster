# =============================================================================
# Internal PKI - Self-signed CA and ClusterIssuer
# =============================================================================
# Creates a self-signed Root CA and a ClusterIssuer that uses it to issue
# certificates for internal mTLS communication.
#
# Certificate chain:
#   Self-signed ClusterIssuer (bootstrap)
#     └── Internal Root CA Certificate
#           └── Internal CA ClusterIssuer (issues service certs)
#
# The trust bundle distributes the Root CA to all mTLS-enabled namespaces.
# =============================================================================

resource "kubernetes_manifest" "selfsigned_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name   = "selfsigned-issuer"
      labels = local.common_labels
    }
    spec = {
      selfSigned = {}
    }
  }
}

resource "kubernetes_manifest" "internal_root_ca" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.internal_ca.name
      namespace = local.cert_manager_ns
      labels    = local.common_labels
    }
    spec = {
      isCA        = true
      commonName  = "${var.internal_ca.name}-ca"
      secretName  = "${var.internal_ca.name}-secret"
      duration    = "${var.internal_ca.validity.hours}h"
      renewBefore = "${var.internal_ca.validity.renew_before}h"
      privateKey = {
        algorithm = "ECDSA"
        size      = 256 # P-256
      }
      issuerRef = {
        name  = kubernetes_manifest.selfsigned_issuer.manifest.metadata.name
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }

  depends_on = [kubernetes_manifest.selfsigned_issuer]
}

# -----------------------------------------------------------------------------
# Internal CA ClusterIssuer (for issuing service certificates)
# -----------------------------------------------------------------------------
resource "kubernetes_manifest" "internal_ca_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name   = var.internal_ca.issuer_name
      labels = local.common_labels
    }
    spec = {
      ca = {
        secretName = "${var.internal_ca.name}-secret"
      }
    }
  }

  depends_on = [kubernetes_manifest.internal_root_ca]
}

# -----------------------------------------------------------------------------
# Trust Bundle (distributes CA to all mTLS-enabled namespaces)
# -----------------------------------------------------------------------------
resource "kubernetes_manifest" "internal_trust_bundle" {
  manifest = {
    apiVersion = "trust.cert-manager.io/v1alpha1"
    kind       = "Bundle"
    metadata = {
      name   = var.trust_bundle.name
      labels = local.common_labels
    }
    spec = {
      sources = [
        {
          secret = {
            name = "${var.internal_ca.name}-secret"
            key  = "ca.crt"
          }
        }
      ]
      target = {
        configMap = {
          key = "ca-certificates.crt"
        }
        namespaceSelector = {
          matchLabels = {
            (var.trust_bundle.namespace_label) = "true"
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.trust_manager,
    kubernetes_manifest.internal_root_ca
  ]
}
