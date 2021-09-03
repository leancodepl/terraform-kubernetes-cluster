terraform {
  required_providers {
    azuread = ">= 2.1"
    azurerm = ">= 2.74"
    random  = ">= 3.1"
    helm    = ">= 2.3"
    kubernetes = {
      source  = "kubernetes"
      version = ">= 2.4"
    }
  }
}

locals {
  tags = merge(var.tags, {
    cluster_name = var.prefix
  })
  ns_labels = {
    importance = "high",
    kind       = "system",
  }
}

resource "azurerm_resource_group" "cluster" {
  name     = var.resource_group_name
  location = var.resource_group_location

  tags = local.tags
}
