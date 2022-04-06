variable "name_prefix" {
  description = "The prefix used in AD configuration"
  type        = string
}

variable "prefix" {
  description = "Resources prefix"
  type        = string
}

variable "resource_group_name" {
  description = "The name of resource group"
  type        = string
}

variable "resource_group_location" {
  description = "The location of resource group"
  type        = string
}

variable "domain" {
  description = "Domain used by the cluster"
  type        = string
}

variable "address_space" {
  description = "Cluster address space, specified in CIDR notation. It is assumed to be /16 or less"
  type        = string
}

variable "node_pool_network_size" {
  description = "The size (in bits) of the node pool subnet. It is cidrsubnet-ted to the address space. Defaults to 4."
  type        = number
  default     = 4
}

variable "tags" {
  description = "Additional tags used by the cluster"
  type        = map(any)
}

variable "cluster_config" {
  description = "Configuration of the cluster"
  type = object({
    version        = string,
    loadbalancer   = string,
    network_policy = string,
    sku_tier       = optional(string),
    default_pool = object({
      vm_size             = string,
      os_disk_size_gb     = string,
      max_pods            = number,
      count               = number,
      min_count           = number,
      max_count           = number,
      enable_auto_scaling = bool,
      version             = string,
      node_taints         = list(string)
    }),
    access = object({
      admin_access_group   = string,
      dev_access_group     = string,
      authorized_ip_ranges = list(string)
    })
  })
}

variable "peered_network" {
  description = "The id of the network that the cluster network will peer to"
  default     = ""
  type        = string
}

variable "datadog" {
  description = "DataDog configuration"
  type = object({
    secret = string,
    config = map(any)
  })
}

variable "traefik" {
  description = "Traefik configuration"
  type = object({
    args      = list(string),
    config    = map(any),
    acme_mail = string,
  })
  default = {
    args      = [],
    config    = {},
    acme_mail = "",
  }
}

variable "traefik_ip_config" {
  description = "The configuration of Traefik IP address"
  type = object({
    sku   = string,
    zones = optional(list(string))
  })
}

variable "aad_pod_identity" {
  description = "AAD Pod Identity configuration"
  type = object({
    config = map(any),
  })
  default = {
    config = {}
  }
}

variable "deploy_external_dns" {
  description = "Whether to deploy External DNS"
  type        = bool
  default     = true
}

variable "deploy_kube_state_metrics" {
  description = "Whether to deploy kube-state-metrics"
  type        = bool
  default     = true
}

variable "deploy_opentelemetry_collector" {
  description = "Whether to deploy opentelemetry-collector"
  type        = bool
  default     = true
}

variable "opentelemetry" {
  description = "OpenTelemetry Collector configuration"
  type = object({
    image = string,
    limiter = object({
      ballast_size_mib = number,
      limit_mib        = number,
      spike_limit_mib  = number,
    }),
    resources = object({
      limits = object({
        cpu    = string,
        memory = string,
      }),
      requests = object({
        cpu    = string,
        memory = string,
      }),
    }),
    tolerations = optional(list(object({
      key      = string,
      operator = string,
      value    = optional(string),
      effect   = string,
    }))),
  })
  default = {
    image = "leancode.azurecr.io/otelcol:v0.2.0",
    limiter = {
      ballast_size_mib = 165,
      limit_mib        = 400,
      spike_limit_mib  = 100,
    },
    resources = {
      limits = {
        cpu    = "500m",
        memory = "500Mi",
      },
      requests = {
        cpu    = "100m",
        memory = "100Mi",
      },
    },
    tolerations = [],
  }
}
