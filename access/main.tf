terraform {
  required_providers {
    kubernetes = ">= 3.0"
  }
}

locals {
  ns_labels = {
    importance = "high",
    kind       = "system",
  }
}