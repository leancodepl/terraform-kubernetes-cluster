terraform {
  required_version = ">= 1.14"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.7"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.56"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7"
    }
  }
}

locals {
  tags = merge(var.tags, {
    cluster_name = var.prefix
  })

  cluster_name        = "${var.prefix}-k8s-cluster"
  normalized_location = lower(replace(var.resource_group.location, " ", ""))
  node_resource_group = coalesce(var.node_resource_group, "MC_${var.resource_group.name}_${local.cluster_name}_${local.normalized_location}")
}
