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

