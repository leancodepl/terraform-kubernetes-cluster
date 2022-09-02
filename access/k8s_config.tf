data "azurerm_client_config" "current" {}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.cluster.kube_admin_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.cluster_ca_certificate)
}

resource "kubernetes_secret" "service_account" {
  metadata {
    name      = "azure-service-account"
    namespace = "kube-system"
  }

  data = {
    subscription_id = data.azurerm_client_config.current.subscription_id
    tenant_id       = data.azurerm_client_config.current.tenant_id

    resource_group = azurerm_resource_group.cluster.name
  }

  depends_on = [azurerm_kubernetes_cluster.cluster]
}

resource "kubernetes_cluster_role_binding" "admin_access" {
  metadata {
    name = "leancode-cluster-admins"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "Group"
    api_group = "rbac.authorization.k8s.io"
    name      = var.cluster_config.access.admin_access_group
  }
}

resource "kubernetes_cluster_role_binding" "dev_access_to_cluster" {
  metadata {
    name = "leancode-cluster-viewers"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }
  subject {
    kind      = "Group"
    api_group = "rbac.authorization.k8s.io"
    name      = var.cluster_config.access.dev_access_group
  }
}

resource "kubernetes_role_binding" "admin_access_to_default_ns" {
  metadata {
    name      = "leancode-cluster-viewers"
    namespace = "default"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }
  subject {
    kind      = "Group"
    api_group = "rbac.authorization.k8s.io"
    name      = var.cluster_config.access.dev_access_group
  }
}

resource "azurerm_role_assignment" "dev_access_to_clusteruser_kubeconfig" {
  scope                = azurerm_kubernetes_cluster.cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.cluster_config.access.dev_access_group
}
