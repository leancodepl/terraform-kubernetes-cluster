terraform {
  required_providers {
    azuread = ">= 1.6"
    azurerm = ">= 2.69"
    random  = ">= 3.1"
    helm    = ">= 2.2"
    kubernetes = {
      source  = "kubernetes"
      version = ">= 2.3"
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
