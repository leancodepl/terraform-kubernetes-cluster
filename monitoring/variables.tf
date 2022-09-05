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

variable "opentelemetry_image" {
  description = "The image used by OTelCol agent."
  type        = string
  default     = "otel/opentelemetry-collector-contrib:0.59.0"
}

variable "opentelemetry_resources" {
  description = "A resource requests/limits for OTelCol agent."
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

variable "opentelemetry_config" {
  description = "The configuration of OTelCol agent."
  type        = map(any)
  default     = null
}

variable "opentelemetry_ports" {
  description = "A list of open ports on OTelCol agent."
  type        = set(number)
  default     = [55680, 55681]
}

variable "opentelemetry_tolerations" {
  description = "A list of tolerations for OTelCol agent."
  type = list(object({
    key      = string,
    operator = string,
    value    = optional(string),
    effect   = string,
  }))
  default = []
}

