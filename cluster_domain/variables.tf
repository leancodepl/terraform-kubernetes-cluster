variable "plugin" {
  description = "The output of cluster module for plugins."
  type = object({
    prefix                      = string
    cluster_id                  = string
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
