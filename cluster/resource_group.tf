resource "azurerm_resource_group" "cluster" {
  name     = var.resource_group.name
  location = var.resource_group.location

  tags = local.tags
}
