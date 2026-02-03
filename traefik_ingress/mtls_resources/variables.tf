# =============================================================================
# mTLS Resources Submodule - Variables
# =============================================================================
# This submodule creates mTLS-specific Kubernetes resources:
# - Client certificate for presenting to mTLS backends
# - CA bundle Secret for verifying backend server certificates
#
# Designed to be reusable by both traefik_ingress and tests.
# =============================================================================

variable "mtls_config" {
  description = "mTLS configuration from mtls module. Pass module.mtls.traefik_config."
  type = object({
    issuer_name            = string
    issuer_kind            = string
    issuer_group           = string
    trust_bundle_name      = string
    root_ca_secret_name    = string
    ca_secret_namespace    = string
    namespace_label        = string
    cert_manager_namespace = string
  })
}

variable "namespace" {
  description = "Target namespace for mTLS resources"
  type        = string
}

variable "service_name" {
  description = "Service name for certificate DNS names"
  type        = string
  default     = "traefik"
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

variable "certificate_duration" {
  description = "Certificate validity duration"
  type        = string
  default     = "24h"
}

variable "certificate_renew_before" {
  description = "Renew certificate before this duration before expiry"
  type        = string
  default     = "1h"
}
