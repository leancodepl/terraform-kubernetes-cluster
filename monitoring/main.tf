terraform {
  required_providers {
    kubernetes = ">= 2.32"
    helm       = ">= 2.15"
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
  otel_labels = merge(local.ns_labels, {
    component = "opentelemetry-collector",
  })
  datadog_labels = merge(local.ns_labels, {
    component = "datadog",
  })
}

resource "kubernetes_namespace" "main" {
  metadata {
    name   = "monitoring"
    labels = local.ns_labels
  }
}