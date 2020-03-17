output "cluster_server_user" {
  value = {
    application_id        = azuread_application.server.application_id
    service_principal_id  = azuread_service_principal.server.id
    service_principal_key = random_string.server_secret.result
  }
}

output "cluster_client_user" {
  value = {
    application_id       = azuread_application.client.application_id
    service_principal_id = azuread_service_principal.client.id
  }
}

output "cluster_service_user" {
  value = {
    application_id        = azuread_application.service.application_id
    service_principal_id  = azuread_service_principal.service.id
    service_principal_key = random_string.service_secret.result
  }
}

output "cluster" {
  value = {
    id                = azurerm_kubernetes_cluster.cluster.id
    kubeconfig        = azurerm_kubernetes_cluster.cluster.kube_config_raw
    kube_admin_config = azurerm_kubernetes_cluster.cluster.kube_admin_config.0
  }
}

output "domain" {
  value = {
    name_servers = azurerm_dns_zone.cluster_domain.name_servers
  }
}

output "networking" {
  value = {
    vnet_id = azurerm_virtual_network.cluster.id
  }
}
