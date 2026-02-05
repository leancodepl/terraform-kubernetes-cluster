variable "plugin" {
  description = "The output of cluster module for plugins."
  type = object({
    prefix = string
  })
}

variable "datadog_keys" {
  description = "A DataDog API and APP key for the DataDog agent and OT collector."
  sensitive   = true
  type = object({
    api = string
    app = string
  })
}

variable "datadog_config" {
  description = "A configuration of DataDog Helm chart."
  type        = map(any)
  default     = {}
}

variable "datadog_resources" {
  description = "A resource requests/limits for DataDog pods."
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
      cpu    = "50m"
      memory = "200Mi"
    }
    limits = {
      cpu    = "0.5"
      memory = "512Mi"
    }
  }
}

variable "datadog_apm_ignore" {
  description = "Filters that will be applied to APM"
  type = object({
    by_resouce = optional(list(string), []),
    by_tag     = optional(list(string), []),
  })
  default = {
    by_resouce = ["persistence.sql.NextMessages"]
  }
}

variable "datadog_env" {
  description = "Environment variables to pass to the Datadog Helm chart. Use this instead of constructing `datadog_config.env` yourself."
  type        = map(string)
  default     = {}
}

variable "datadog_chart_version" {
  description = "Version of the Datadog Helm chart."
  type        = string
  default     = "3.154.1" # pinned for backward compatibility
}
