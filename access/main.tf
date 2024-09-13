terraform {
  required_providers {
    kubernetes = ">= 2.32"
  }
}

locals {
  ns_labels = {
    importance = "high",
    kind       = "system",
  }
}