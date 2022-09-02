output "identities" {
  description = "The identities assigned to the cluster and kubelets."

  value = {
    cluster_identity_id           = azurerm_user_assigned_identity.cluster_identity.id
    cluster_identity_principal_id = azurerm_user_assigned_identity.cluster_identity.principal_id

    kubelet_identity = azurerm_kubernetes_cluster.cluster.kubelet_identity
  }
}

output "cluster" {
  description = "The basic description of the cluster."
  value = {
    id                     = azurerm_kubernetes_cluster.cluster.id
    resource_group_id      = azurerm_resource_group.cluster.id
    node_resource_group_id = data.azurerm_resource_group.cluster_node_group.id
  }
}

output "access" {
  description = "The access data to the cluster."
  sensitive   = true
  value = {
    kube_config           = azurerm_kubernetes_cluster.cluster.kube_config.0
    kube_config_raw       = azurerm_kubernetes_cluster.cluster.kube_config_raw
    kube_admin_config     = azurerm_kubernetes_cluster.cluster.kube_admin_config.0
    kube_admin_config_raw = azurerm_kubernetes_cluster.cluster.kube_admin_config_raw
  }
}

output "kubernetes_provider" {
  description = "The raw data that allows to initialize Kubernetes-accessing providers."
  sensitive   = true
  value = {
    host                   = azurerm_kubernetes_cluster.cluster.kube_admin_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.cluster_ca_certificate)
  }
}

output "networking" {
  description = "The IDs of networking objects."
  value = {
    vnet_id           = azurerm_virtual_network.cluster.id
    default_node_pool = azurerm_subnet.default_node_pool.id
  }
}

output "plugin" {
  description = "The output that you need to pass to plugins for them to work."
  sensitive   = true
  value = {
    prefix = var.prefix

    cluster_id                  = azurerm_kubernetes_cluster.cluster.id
    cluster_resource_group_name = azurerm_resource_group.cluster.id
    cluster_identity_id         = azurerm_user_assigned_identity.cluster_identity.id
    cluster_identity_client_id  = azurerm_user_assigned_identity.cluster_identity.client_id

    tags = local.tags
  }
}
