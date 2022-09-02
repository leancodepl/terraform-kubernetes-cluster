resource "kubernetes_cluster_role_binding" "admin_access" {
  for_each = var.admins

  metadata {
    name = "cluster-admins-${each.key}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "Group"
    api_group = "rbac.authorization.k8s.io"
    name      = each.key
  }
}

resource "kubernetes_cluster_role_binding" "view_access" {
  for_each = var.viewers

  metadata {
    name = "cluster-view-${each.key}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind      = "Group"
    api_group = "rbac.authorization.k8s.io"
    name      = each.key
  }
}

resource "azurerm_role_assignment" "access_to_clusteruser_kubeconfig" {
  for_each = setunion(var.viewers, var.admins)

  scope                = var.plugin.cluster_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = each.key
}
