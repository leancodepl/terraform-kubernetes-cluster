variable "plugin" {
  description = "The output of cluster module for plugins."

  type = object({
    prefix = string
    tags   = map(string)
  })
}

variable "monitoring_plugin" {
  description = "The output of monitoring cluster."

  type = object({
    namespace_name = string
  })
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
      memory = "100Mi"
    }
  }
}

