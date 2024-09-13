terraform {
  required_version = ">= 1.3"

  required_providers {
    azuread    = ">= 2.53"
    azurerm    = ">= 4.2"
    kubernetes = ">= 2.32"
    random     = ">= 3.6"
  }
}

locals {
  tags = merge(var.tags, {
    cluster_name = var.prefix
  })
}

data "azurerm_client_config" "current" {}