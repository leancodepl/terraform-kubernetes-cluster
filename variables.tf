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

variable "ad_config" {
  description = "AD configuration"
  type = object({
    service_secret_end_date = string,
  })
  default = {
    service_secret_end_date = "2022-06-10T12:00:00Z",
  }
}

variable "cluster_config" {
  description = "Configuration of the cluster"
  type = object({
    version        = string,
    loadbalancer   = string,
    network_policy = string,
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
    args   = list(string),
    config = map(any),
  })
  default = {
    args   = [],
    config = {},
  }
}

variable "deploy_aad_pod_identity" {
  type    = bool
  default = true
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

variable "use_user_assigned_identity" {
  description = "Indicates whether to use managed, UserAssigned identity or raw service principal. Disabled to allow manual migration."
  type        = bool
  default     = false
}
