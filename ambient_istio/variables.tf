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
      cpu    = "200m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "2"
      memory = "1Gi"
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
      cpu    = "500m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2"
      memory = "4Gi"
    }
  }
}

variable "istio_config" {
  description = "Custom Helm values to merge into the Istio chart configuration."
  type        = map(any)
  default     = {}
}
