# =============================================================================
# mTLS Resources Submodule - Outputs
# =============================================================================
# Exposes secret names for use by traefik-options chart.
# =============================================================================

output "client_cert_secret_name" {
  description = "Name of the client certificate Secret"
  value       = kubernetes_manifest.client_cert.manifest.spec.secretName
}

output "ca_bundle_secret_name" {
  description = "Name of the CA bundle Secret"
  value       = kubernetes_secret_v1.ca_bundle.metadata[0].name
}
