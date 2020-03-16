resource "azurerm_dns_zone" "cluster_domain" {
  name                = var.domain
  resource_group_name = azurerm_resource_group.cluster.name

  tags = local.tags
}
