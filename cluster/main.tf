terraform {
  required_version = ">= 1.3"

  required_providers {
    azuread    = ">= 2.28"
    azurerm    = ">= 3.21"
    random     = ">= 3.4"
    kubernetes = ">= 2.13"
  }
}

locals {
  tags = merge(var.tags, {
    cluster_name = var.prefix
  })
}

data "azurerm_client_config" "current" {}

