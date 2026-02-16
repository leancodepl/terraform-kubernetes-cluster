variable "plugin" {
  description = "The output of cluster module for plugins."
  type = object({
    prefix          = string
    cluster_version = string
  })

  validation {
    condition     = can(regex("^\\d{1,2}\\.\\d{1,2}\\.\\d{1,2}$", trimspace(var.plugin.cluster_version)))
    error_message = "plugin.cluster_version must match cluster module version format (for example 1.31.0)."
  }
}

variable "istio_version" {
  description = "The version of Istio Helm charts to install."
  type        = string

  validation {
    condition     = can(regex("^v?[0-9]+\\.[0-9]+([.][0-9A-Za-z+-]+)*$", trimspace(var.istio_version)))
    error_message = "istio_version must start with a numeric major.minor (for example 1.28 or 1.28.3)."
  }
}

variable "compatibility" {
  description = "Compatibility validation configuration for Kubernetes and Gateway API checks."
  type = object({
    kubernetes = optional(object({
      mode               = optional(string, "supported")
      support_status_url = optional(string, "https://raw.githubusercontent.com/istio/istio.io/master/data/compatibility/supportStatus.yml")
    }), {})
    gateway_api = optional(object({
      mode                 = optional(string, "enforced")
      min_version_override = optional(string, null)
    }), {})
  })
  default = {}

  validation {
    condition     = contains(["skip", "supported", "tested"], var.compatibility.kubernetes.mode)
    error_message = "compatibility.kubernetes.mode must be one of: skip, supported, tested."
  }

  validation {
    condition     = can(regex("^https?://", trimspace(var.compatibility.kubernetes.support_status_url)))
    error_message = "compatibility.kubernetes.support_status_url must be a valid HTTP/HTTPS URL."
  }

  validation {
    condition     = contains(["enforced", "skip"], var.compatibility.gateway_api.mode)
    error_message = "compatibility.gateway_api.mode must be one of: enforced, skip."
  }

  validation {
    condition = var.compatibility.gateway_api.min_version_override == null || can(
      regex("^v?[0-9]+\\.[0-9]+\\.[0-9]+$", trimspace(var.compatibility.gateway_api.min_version_override))
    )
    error_message = "compatibility.gateway_api.min_version_override must be a semantic version (for example v1.4.0) when set."
  }
}

variable "install_gateway_api_crds" {
  description = "Gateway API CRD management mode: install, install_and_take_ownership, or none."
  type        = string
  default     = "install"

  validation {
    condition     = contains(["none", "install", "install_and_take_ownership"], var.install_gateway_api_crds)
    error_message = "install_gateway_api_crds must be one of: none, install, install_and_take_ownership."
  }
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
