terraform {
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
    app        = "monitoring"
  }
}

locals {
  datadog_labels = merge(local.ns_labels, {
    component = "datadog",
  })
}

resource "kubernetes_namespace_v1" "main" {
  metadata {
    name   = "monitoring"
    labels = local.ns_labels
  }
}