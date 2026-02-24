variable "plugin" {
  description = "The output of cluster module for plugins."
  type = object({
    prefix                      = string
    cluster_name                = string
    cluster_resource_group_name = string
    cluster_identity_id         = string
    cluster_identity_client_id  = string
    tags                        = map(string)
  })
}

variable "domain_name" {
  description = "The domain name of the cluster."
  type        = string
}

variable "config" {
  description = "External DNS configuration."
  type        = map(any)
  default     = {}
}

variable "manage_helm_release" {
  description = "Whether this module should manage the External DNS Helm release."
  type        = bool
  default     = true
}

variable "resources" {
  description = "The requests and limits of External DNS pod."

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
      cpu    = "10m"
      memory = "20Mi"
    }
    limits = {
      cpu    = "100m"
      memory = "50Mi"
    }
  }
}

variable "external_dns_chart_version" {
  description = "Version of the External DNS Helm chart. See: https://kubernetes-sigs.github.io/external-dns."
  type        = string
  default     = "1.19.0" # pinned for backward compatibility
}
