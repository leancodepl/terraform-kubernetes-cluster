output "identities" {
  value = {
    cluster_identity_id           = azurerm_user_assigned_identity.cluster_identity.id
    cluster_identity_principal_id = azurerm_user_assigned_identity.cluster_identity.principal_id

    kubelet_identity = azurerm_kubernetes_cluster.cluster.kubelet_identity
  }
  sensitive = true
}

output "cluster" {
  sensitive = true
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
