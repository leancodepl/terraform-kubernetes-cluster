output "domain" {
  description = "A description of the Azure domain resource."
  value = {
    zone_id             = azurerm_dns_zone.cluster_domain.id
    zone_name           = azurerm_dns_zone.cluster_domain.name
    resource_group_name = azurerm_dns_zone.cluster_domain.resource_group_name
    name_servers        = azurerm_dns_zone.cluster_domain.name_servers
  }
}
