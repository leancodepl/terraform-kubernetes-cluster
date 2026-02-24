output "domain" {
  description = "A description of the Azure domain resource."
  value = {
    zone_id             = azurerm_dns_zone.cluster_domain.id
    zone_name           = azurerm_dns_zone.cluster_domain.name
    resource_group_name = azurerm_dns_zone.cluster_domain.resource_group_name
    name_servers        = azurerm_dns_zone.cluster_domain.name_servers
  }
}

output "helm" {
  description = "Helm chart configuration produced by this module, keyed by release name. Values are structured objects; call yamlencode(values) if a YAML string is needed."
  value = {
    (local.external_dns_release.name) = {
      namespace             = kubernetes_namespace_v1.external_dns.metadata[0].name
      repository            = local.external_dns_release.repository
      chart                 = local.external_dns_release.chart
      minimum_chart_version = local.external_dns_release.minimum_chart_version
      values                = local.external_dns_values
      parameters            = local.external_dns_parameters
    }
  }
}
