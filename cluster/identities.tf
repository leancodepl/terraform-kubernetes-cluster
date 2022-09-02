resource "azurerm_user_assigned_identity" "cluster_identity" {
  name                = "${var.prefix}-k8s-cluster-identity"
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "service_contributor" {
  scope                = azurerm_resource_group.cluster.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster_identity.principal_id
}

resource "azurerm_role_assignment" "aad_managed_identity_operator" {
  scope                = data.azurerm_resource_group.cluster_node_group.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "aad_vm_contributor" {
  scope                = data.azurerm_resource_group.cluster_node_group.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "aad_managed_identity_operator_for_cluster_identity" {
  scope                = azurerm_user_assigned_identity.cluster_identity.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
}
