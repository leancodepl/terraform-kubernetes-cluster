terraform {
  required_providers {
    azurerm    = ">= 4.56"
    kubernetes = ">= 3.0"
    helm       = ">= 3.0"
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
