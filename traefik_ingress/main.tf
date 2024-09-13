terraform {
  required_providers {
    azurerm    = ">= 4.2"
    kubernetes = ">= 2.32"
    helm       = ">= 2.15"
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
