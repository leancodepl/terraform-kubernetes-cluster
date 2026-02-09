variable "plugin" {
  description = "The output of cluster module for plugins."
  type = object({
    prefix = string
    tags   = map(string)
  })
}

variable "istio_version" {
  description = "The version of Istio Helm charts to install."
  type        = string
  default     = "1.28.3"
}

variable "install_gateway_api_crds" {
  description = "Install Kubernetes Gateway API CRDs. Set to false if already installed on the cluster by other means."
  type        = bool
  default     = true
}

variable "ztunnel_resources" {
  description = "Resource requests/limits for ztunnel DaemonSet pods (runs on every node)."
  type = object({
    requests = object({
      memory = string
      cpu    = string
    })
    limits = object({
      memory = string
      cpu    = string
    })
  })
  default = {
    requests = {
      cpu    = "50m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "istiod_resources" {
  description = "Resource requests/limits for istiod control plane pods."
  type = object({
    requests = object({
      memory = string
      cpu    = string
    })
    limits = object({
      memory = string
      cpu    = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "1Gi"
    }
  }
}

variable "istio_config" {
  description = "Per-chart custom Helm values to merge into the Istio chart configuration."
  type = object({
    base    = optional(map(any), {})
    istiod  = optional(map(any), {})
    cni     = optional(map(any), {})
    ztunnel = optional(map(any), {})
  })
  default = {}
}
