terraform {
  required_version = ">= 1.14"

  required_providers {
    azuread    = ">= 3.7"
    azurerm    = ">= 4.56"
    kubernetes = ">= 3.0"
    random     = ">= 3.7"
  }
}

locals {
  tags = merge(var.tags, {
    cluster_name = var.prefix
  })
}

data "azurerm_client_config" "current" {}