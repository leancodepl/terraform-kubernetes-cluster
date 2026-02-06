terraform {
  required_version = ">= 1.14"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0"
    }
  }
}

locals {
  ns_labels = {
    importance = "high"
    kind       = "system"
    app        = "ambient-istio"
  }
}
