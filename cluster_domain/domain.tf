resource "azurerm_dns_zone" "cluster_domain" {
  name                = var.domain_name
  resource_group_name = var.plugin.cluster_resource_group_name

  tags = var.plugin.tags
}
