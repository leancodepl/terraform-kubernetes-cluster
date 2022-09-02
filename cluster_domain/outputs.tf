output "name_servers" {
  description = "A list of name servers for the zone."
  value       = azurerm_dns_zone.cluster_domain.name_servers
}
