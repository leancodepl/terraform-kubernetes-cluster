terraform {
  required_providers {
    kubernetes = ">= 2.13"
    helm       = ">= 2.6"
  }
}

locals {
  ns_labels = {
    importance = "high",
    kind       = "system",
  }
}
