resource "azurerm_role_assignment" "dev_access_to_clusteruser_kubeconfig" {
  scope                = azurerm_kubernetes_cluster.cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.access.dev_access_group
}
