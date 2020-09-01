terraform {
  required_providers {
    azuread    = ">= 0.9"
    azurerm    = ">= 2.8.0"
    kubernetes = ">= 1.11.2"
    random     = ">= 2.2"
    helm       = ">= 1.2.4"
  }
}

locals {
  tags = merge(var.tags, {
    cluster_name = var.prefix
  })
}

resource "azurerm_resource_group" "cluster" {
  name     = var.resource_group_name
  location = var.resource_group_location

  tags = local.tags
}
