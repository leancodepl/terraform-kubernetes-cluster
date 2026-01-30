variable "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed (must exist)"
  type        = string
  default     = "cert-manager"
}

variable "helm_versions" {
  description = "Helm chart versions for mTLS components"
  type = object({
    csi_driver    = optional(string, "v0.12.0")
    trust_manager = optional(string, "v0.20.2")
  })
  default = {}
}

variable "internal_ca" {
  description = "Internal Root CA configuration"
  type = object({
    name        = optional(string, "internal-root-ca")
    issuer_name = optional(string, "internal-ca-issuer")
    validity = optional(object({
      hours        = optional(number, 87600) # 10 years
      renew_before = optional(number, 720)   # 30 days
    }), {})
  })
  default = {}
}

variable "trust_bundle" {
  description = "Trust bundle configuration for CA distribution"
  type = object({
    name            = optional(string, "internal-ca-bundle")
    namespace_label = optional(string, "mtls.leancode.pl/enabled")
  })
  default = {}
}
