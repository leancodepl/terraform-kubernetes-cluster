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
