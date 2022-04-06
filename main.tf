terraform {
  experiments = [module_variable_optional_attrs]
  required_providers {
    azuread = ">= 2.19"
    azurerm = ">= 3.0"
    random  = ">= 3.1"
    helm    = ">= 2.5"
    kubernetes = {
      source  = "kubernetes"
      version = ">= 2.9"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.cluster.kube_admin_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config.0.cluster_ca_certificate)
  }
}

locals {
  tags = merge(var.tags, {
    cluster_name = var.prefix
  })
  ns_labels = {
    importance = "high",
    kind       = "system",
  }
}

resource "azurerm_resource_group" "cluster" {
  name     = var.resource_group_name
  location = var.resource_group_location

  tags = local.tags
}
