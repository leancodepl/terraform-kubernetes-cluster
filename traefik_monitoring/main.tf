terraform {
  required_providers {
    kubernetes = ">= 2.13"
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
}
