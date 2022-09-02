terraform {
  required_providers {
    azuread    = ">= 2.28"
    azurerm    = ">= 3.21"
    random     = ">= 3.4"
    kubernetes = ">= 2.13"
  }
  experiments = [module_variable_optional_attrs]
}

locals {
  tags = merge(var.tags, {
    cluster_name = var.prefix
  })
}

data "azurerm_client_config" "current" {}

