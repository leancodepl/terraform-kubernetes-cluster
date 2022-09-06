terraform {
  required_providers {
    kubernetes = ">= 2.13"
  }
}

locals {
  ns_labels = {
    importance = "high",
    kind       = "system",
  }
}
