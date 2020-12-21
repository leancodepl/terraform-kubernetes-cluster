data "azurerm_client_config" "current" {}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.cluster.kube_admin_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.cluster_ca_certificate)
}

provider "kubernetes-old" {
  host                   = azurerm_kubernetes_cluster.cluster.kube_admin_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.cluster_ca_certificate)
  load_config_file       = false
}

resource "kubernetes_manifest" "service_account_secret" {
  manifest = {
    apiVersion = "v1"
    kind       = "Secret"
    type       = "Opaque"
    metadata = {
      name      = "azure-service-account"
      namespace = "kube-system"
    }

    data = {
      subscription_id = base64encode(data.azurerm_client_config.current.subscription_id),
      tenant_id       = base64encode(data.azurerm_client_config.current.tenant_id),

      client_id     = base64encode(azuread_service_principal.service.application_id),
      client_secret = base64encode(random_password.service_secret.result),

      resource_group = base64encode(azurerm_resource_group.cluster.name),
    }
  }

  depends_on = [azurerm_kubernetes_cluster.cluster]
}

resource "kubernetes_manifest" "admin_access_crb" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "leancode-cluster-admins"
    }

    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "cluster-admin"
    }
    subjects = [{
      kind     = "Group"
      apiGroup = "rbac.authorization.k8s.io"
      name     = var.cluster_config.access.admin_access_group
    }]
  }
}

resource "kubernetes_manifest" "dev_access_to_cluster_crb" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "leancode-cluster-viewers"
    }

    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "view"
    }
    subjects = [{
      kind     = "Group"
      apiGroup = "rbac.authorization.k8s.io"
      name     = var.cluster_config.access.dev_access_group
    }]
  }
}

resource "kubernetes_manifest" "admin_access_to_default_ns_rb" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "RoleBinding"
    metadata = {
      name      = "leancode-cluster-viewers"
      namespace = "default"
    }

    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "admin"
    }
    subjects = [{
      kind     = "Group"
      apiGroup = "rbac.authorization.k8s.io"
      name     = var.cluster_config.access.dev_access_group
    }]
  }
}

resource "azurerm_role_assignment" "dev_access_to_clusteruser_kubeconfig" {
  scope                = azurerm_kubernetes_cluster.cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.cluster_config.access.dev_access_group
}
