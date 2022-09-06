terraform {
  required_providers {
    azurerm    = ">= 3.21"
    kubernetes = ">= 2.13"
    helm       = ">= 2.6"
  }
}

locals {
  ns_labels = {
    importance = "high"
    kind       = "system"
    app        = "traefik-ingress"
  }
}

data "azurerm_client_config" "current" {}

