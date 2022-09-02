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

variable "args" {
  description = "A list of Traefik command line arguments."
  type        = list(string)
  default     = []
}

variable "config" {
  description = "A configuration for the Traefik Helm chart."
  type        = map(any)
  default     = {}
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
