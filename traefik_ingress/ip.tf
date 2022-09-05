resource "azurerm_public_ip" "traefik_public_ip" {
  name                = "${var.plugin.prefix}-traefik-public-ip"
  resource_group_name = var.plugin.cluster_resource_group_name
  location            = var.plugin.cluster_resource_group_location

  allocation_method = "Static"
  sku               = title(var.plugin.network_config.load_balancer_sku)
  zones             = var.ip_zones

  tags = var.plugin.tags
}
