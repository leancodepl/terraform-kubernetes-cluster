variable "resource_group" {
  description = "The resource group description."
  type = object({
    name     = string,
    location = string
  })
}

variable "prefix" {
  description = "Resources name prefix, plus DNS name of the cluster."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]{1,43}[a-z0-9]$", var.prefix))
    error_message = "The prefix must must contain between 3 and 45 characters, and can contain only letters, numbers, and hyphens. It must start with a letter and must end with a letter or a number."
  }
}

variable "cluster_version" {
  description = "The version of the cluster control plane."
  type        = string

  validation {
    condition     = can(regex("\\d{1,2}\\.\\d{1,2}\\.\\d{1,2}", var.cluster_version))
    error_message = "The version must be correct"
  }
}

variable "address_space" {
  description = "Cluster address space, specified in CIDR notation. It is assumed to be /16 or less. Needs to be outside of 10.255.0.0/16 and 172.17.0.0/16 spaces."
  type        = string
}

variable "default_node_pool_subnet_size" {
  description = "The size (in bits) of the default node pool subnet. It is cidrsubnet-ted to the address space. Defaults to 4."
  type        = number
  default     = 4
}

variable "default_node_pool_service_endpoints" {
  description = "The service endpoints that will be enabled on the node pool subnet."
  type        = set(string)
  default     = ["Microsoft.KeyVault", "Microsoft.Sql"]
}

variable "tags" {
  description = "Additional tags used by the cluster"
  type        = map(any)
}

variable "access" {
  description = "Configure access rules to the cluster."
  type = object({
    admin_access_group = string,
  })
}

variable "network" {
  description = "Network configuration"
  type = object({
    load_balancer_sku = string,
    network_policy    = optional(string),
  })
}

variable "default_pool" {
  description = "Configuration of the default node pool. Should be used as a system node pool only."
  type = object({
    vm_size         = string,
    os_disk_size_gb = string,
    max_pods        = number,
    version         = optional(string),
    node_taints     = optional(list(string)),

    enable_auto_scaling = optional(bool),
    min_count           = optional(number),
    max_count           = optional(number),
    count               = optional(number),
  })
}

variable "peered_network" {
  description = "The id of the network that the cluster network will peer to."
  default     = ""
  type        = string
}
