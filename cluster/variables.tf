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

    auto_scaling_enabled = optional(bool),
    min_count            = optional(number),
    max_count            = optional(number),
    count                = optional(number),
  })

  validation {
    condition     = var.default_pool.auto_scaling_enabled == null || var.default_pool.auto_scaling_enabled == false ? var.default_pool.count != null && var.default_pool.min_count == null && var.default_pool.max_count == null : var.default_pool.count == null && var.default_pool.min_count != null && var.default_pool.max_count != null && var.default_pool.min_count <= var.default_pool.max_count
    error_message = "When auto scaling is enabled, min_count and max_count must be provided. Otherwise, count must be provided."
  }
}

variable "peered_network" {
  description = "The id of the network that the cluster network will peer to."
  default     = ""
  type        = string
}

variable "sku_tier" {
  description = "The SKU Tier that should be used for this Kubernetes Cluster."
  type        = string
  default     = "Free"

  validation {
    condition     = var.sku_tier == "Free" || var.sku_tier == "Paid"
    error_message = "The SKU tier might be `Free` or `Paid`."
  }
}

variable "maintenance_window_node_os" {
  description = "Configuration for the maintenance window of node OS upgrades."
  type = object({
    day_of_month = optional(number),
    day_of_week  = optional(string),
    duration     = number,
    frequency    = string,
    interval     = number,
    start_date   = optional(string),
    start_time   = optional(string),
    utc_offset   = optional(string),
    week_index   = optional(string),
    not_allowed = optional(object({
      start = optional(string),
      end   = optional(string),
    }))
  })
  default = null
}

variable "maintenance_window_auto_upgrade" {
  description = "Configuration for the maintenance window of auto upgrades."
  type = object({
    day_of_month = optional(number),
    day_of_week  = optional(string),
    duration     = number,
    frequency    = string,
    interval     = number,
    start_date   = optional(string),
    start_time   = optional(string),
    utc_offset   = optional(string),
    week_index   = optional(string),
    not_allowed = optional(object({
      start = optional(string),
      end   = optional(string),
    }))
  })
  default = null
}

variable "node_os_upgrade_channel" {
  description = "The node OS upgrade channel for the cluster."
  type        = string
  default     = "NodeImage"

  validation {
    condition     = contains(["None", "Unmanaged", "SecurityPatch", "NodeImage"], var.node_os_upgrade_channel)
    error_message = "node_os_upgrade_channel must be one of: None, Unmanaged, SecurityPatch, NodeImage."
  }
}

variable "automatic_upgrade_channel" {
  description = "The automatic upgrade channel for the Kubernetes cluster."
  type        = string
  default     = null

  validation {
    condition     = var.automatic_upgrade_channel == null || contains(["patch", "rapid", "node-image", "stable", "none"], var.automatic_upgrade_channel)
    error_message = "automatic_upgrade_channel must be one of: patch, rapid, node-image, stable, none."
  }
}

variable "node_resource_group" {
  description = "Override for the node resource group name. If not set, defaults to MC_{resource_group}_{cluster_name}_{location}."
  type        = string
  default     = null
}

