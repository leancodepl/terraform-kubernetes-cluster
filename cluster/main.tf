terraform {
  required_version = ">= 1.3"

  required_providers {
    azuread    = ">= 3.3"
    azurerm    = ">= 4.26"
    kubernetes = ">= 2.36"
    random     = ">= 3.7"
  }
}

locals {
  tags = merge(var.tags, {
    cluster_name = var.prefix
  })
}

data "azurerm_client_config" "current" {}