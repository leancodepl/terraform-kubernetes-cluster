resource "azurerm_virtual_network" "cluster" {
  name                = "${var.prefix}-net"
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location

  address_space = [var.address_space]

  tags = local.tags
}

resource "azurerm_subnet" "default_node_pool" {
  name                 = "default-node-pool"
  resource_group_name  = azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.cluster.name

  address_prefixes  = [cidrsubnet(var.address_space, var.default_node_pool_subnet_size, 0)]
  service_endpoints = var.default_node_pool_service_endpoints
}

resource "azurerm_virtual_network_peering" "to_outside" {
  count                     = var.peered_network == "" ? 0 : 1
  name                      = "${var.prefix}-peer-to-outside"
  resource_group_name       = azurerm_resource_group.cluster.name
  virtual_network_name      = azurerm_virtual_network.cluster.name
  remote_virtual_network_id = var.peered_network

  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  allow_virtual_network_access = false
  use_remote_gateways          = false
}
