variable "plugin" {
  description = "The output of cluster module for plugins."
  sensitive   = true
  type        = object({})
}

variable "config" {
  description = "AAD Pod Identity configuration."
  type        = map(any)
  default     = {}
}

variable "resources" {
  description = "The requests and limits of AAD Pod Identity pods."

  type = object({
    mic = object({
      requests = object({
        memory = string,
        cpu    = string
      })
      limits = object({
        memory = string,
        cpu    = string
      })
    })
    nmi = object({
      requests = object({
        memory = string,
        cpu    = string
      })
      limits = object({
        memory = string,
        cpu    = string
      })
    })
  })

  default = {
    mic = {
      requests = {
        cpu    = "100m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
    nmi = {
      requests = {
        cpu    = "100m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
  }
}
