variable "plugin" {
  description = "The output of cluster module for plugins."
  type = object({
    prefix                          = string
    cluster_id                      = string
    cluster_resource_group_name     = string
    cluster_resource_group_location = string
    cluster_identity_id             = string
    cluster_identity_client_id      = string
    tags                            = map(string)

    network_config = object({
      load_balancer_sku = string
    })
  })
}

variable "acme_mail" {
  description = "The e-mail address that will be used for ACME account."
  type        = string
}

variable "resources" {
  description = "The requests and limits of the Traefik pod."

  type = object({
    requests = object({
      memory = string,
      cpu    = string
    })
    limits = object({
      memory = string,
      cpu    = string
    })
  })

  default = {
    requests = {
      cpu    = "100m"
      memory = "50Mi"
    }
    limits = {
      cpu    = "1"
      memory = "256Mi"
    }
  }
}

variable "enable_monitoring" {
  description = "Should Traefik send traces & metrics to OTEL agent"
  type        = bool
  default     = true
}


variable "ip_zones" {
  description = "A list of availability zones where the ingress IP address will be allocated."
  type        = set(number)
  default     = null
}

variable "default_router_rule_syntax" {
  description = "Set default router rule syntax to facilitate v2 -> v3 migration. https://doc.traefik.io/traefik/migration/v2-to-v3-details/#router-rule-matchers"
  type        = string
  default     = "v2"
  validation {
    condition     = contains(["v2", "v3"], var.default_router_rule_syntax)
    error_message = "Provide 'v2' or 'v3'"
  }
}

variable "traefik_config" {
  description = "Helm chart configuration values."
  type        = map(any)
  default     = {}
}

variable "mtls_config" {
  description = "mTLS configuration from mtls module. Pass module.mtls.traefik_config to enable."
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
  default = null
}
