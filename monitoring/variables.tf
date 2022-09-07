variable "plugin" {
  description = "The output of cluster module for plugins."
  type = object({
    prefix = string
    tags   = map(string)
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

