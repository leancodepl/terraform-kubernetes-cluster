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
  type        = map
}

variable "cluster_config" {
  description = "Configuration of the cluster"
  type = object({
    version      = string,
    loadbalancer = string,
    default_pool = object({
      vm_size             = string,
      os_disk_size_gb     = string,
      max_pods            = number,
      count               = number,
      min_count           = number,
      max_count           = number,
      enable_auto_scaling = bool,
      node_taints         = list(string)
    }),
    access = object({
      admin_access_group   = string,
      dev_access_group     = string,
      authorized_ip_ranges = list(string)
    })
  })
}

variable "datadog" {
  description = "DataDog configuration"
  type = object({
    secret = string,
    config = map(string)
  })
}

variable "peered_network" {
  description = "The id of the network that the cluster network will peer to"
  default     = ""
  type        = string
}

variable "traefik" {
  description = "Traefik configuration"
  type = object({
    config_file_name = string
    resources = object({
      limits = object({
        cpu    = string,
        memory = string,
      })
    })
  })
  default = {
    config_file_name = "traefik.toml"
    resources = {
      limits = {
        cpu    = "100m"
        memory = "50m"
      }
    }
  }
}
