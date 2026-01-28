# =============================================================================
# Test Variables
# =============================================================================

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubernetes context to use (defaults to k3d-mtls-test)"
  type        = string
  default     = "k3d-mtls-test"
}

# -----------------------------------------------------------------------------
# Variables passed to the mtls module (using module defaults for testing)
# -----------------------------------------------------------------------------

variable "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  type        = string
  default     = "cert-manager"
}

variable "helm_versions" {
  description = "Helm chart versions for mTLS components"
  type = object({
    csi_driver    = optional(string)
    trust_manager = optional(string)
  })
  default = {}
}

variable "internal_ca" {
  description = "Internal Root CA configuration"
  type = object({
    name        = optional(string)
    issuer_name = optional(string)
    validity = optional(object({
      hours        = optional(number)
      renew_before = optional(number)
    }))
  })
  default = {}
}

variable "trust_bundle" {
  description = "Trust bundle configuration for CA distribution"
  type = object({
    name            = optional(string)
    namespace_label = optional(string)
  })
  default = {}
}
