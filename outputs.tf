output "cluster_server_user" {
  value = {
    application_id        = azuread_application.server.application_id
    service_principal_id  = azuread_service_principal.server.id
    service_principal_key = random_string.server_secret.result
  }
  sensitive = true
}

output "cluster_client_user" {
  value = {
    application_id       = azuread_application.client.application_id
    service_principal_id = azuread_service_principal.client.id
  }
  sensitive = true
}

output "cluster_service_user" {
  value = {
    application_id        = azuread_application.service.application_id
    service_principal_id  = azuread_service_principal.service.id
    service_principal_key = random_string.service_secret.result
  }
  sensitive = true
}

output "cluster" {
  value = {
    kubeconfig        = azurerm_kubernetes_cluster.cluster.kube_config_raw
    kube_admin_config = azurerm_kubernetes_cluster.cluster.kube_admin_config.0

    id                  = azurerm_kubernetes_cluster.cluster.id
    name                = azurerm_kubernetes_cluster.cluster.name
    resource_group_name = azurerm_kubernetes_cluster.cluster.resource_group_name
  }
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.cluster.id
}

output "domain" {
  value = {
    zone_id             = azurerm_dns_zone.cluster_domain.id
    zone_name           = azurerm_dns_zone.cluster_domain.name
    resource_group_name = azurerm_dns_zone.cluster_domain.resource_group_name
    name_servers        = azurerm_dns_zone.cluster_domain.name_servers
  }
}

output "networking" {
  value = {
    vnet_id             = azurerm_virtual_network.cluster.id
    vnet_pool_subnet_id = azurerm_subnet.node_pool.id
  }
}
