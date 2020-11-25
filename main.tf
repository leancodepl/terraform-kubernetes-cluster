terraform {
  required_providers {
    azuread = ">= 1.1"
    azurerm = ">= 2.37.0"
    random  = ">= 3.0"
    helm    = ">= 1.3.2"
    kubernetes = {
      source  = "kubernetes-alpha"
      version = ">= 0.2.1"
    }
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
