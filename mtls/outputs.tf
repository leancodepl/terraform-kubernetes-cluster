# =============================================================================
# mTLS Module Outputs
# =============================================================================
# These outputs are used by consuming modules (e.g., traefik_ingress, application deployments)
# to configure mTLS for their workloads.
# =============================================================================

# Use this for CSI driver volumeAttributes or Certificate resources
output "issuer" {
  description = "Internal CA ClusterIssuer configuration for issuing certificates"
  value = {
    name  = kubernetes_manifest.internal_ca_issuer.manifest.metadata.name
    kind  = "ClusterIssuer"
    group = "cert-manager.io"
  }
}

# Use this to reference the Root CA certificate Secret
output "root_ca" {
  description = "Root CA Secret configuration"
  value = {
    secret_name = "${var.internal_ca.name}-secret"
    namespace   = local.cert_manager_ns
  }
}

# Use this for mounting CA bundles in application Pods
output "trust_bundle" {
  description = "Trust bundle configuration distributed by trust-manager"
  value = {
    name            = kubernetes_manifest.internal_trust_bundle.manifest.metadata.name
    namespace_label = var.trust_bundle.namespace_label
  }
}

# Pass this directly to traefik_ingress module's mtls_config variable
output "traefik_config" {
  description = "Complete mTLS configuration for traefik_ingress module"
  value = {
    issuer_name            = kubernetes_manifest.internal_ca_issuer.manifest.metadata.name
    issuer_kind            = "ClusterIssuer"
    issuer_group           = "cert-manager.io"
    trust_bundle_name      = kubernetes_manifest.internal_trust_bundle.manifest.metadata.name
    root_ca_secret_name    = "${var.internal_ca.name}-secret"
    ca_secret_namespace    = local.cert_manager_ns
    namespace_label        = var.trust_bundle.namespace_label
    cert_manager_namespace = local.cert_manager_ns
  }
}

output "cert_manager_namespace" {
  description = "Namespace where cert-manager and mTLS components are installed"
  value       = local.cert_manager_ns
}
