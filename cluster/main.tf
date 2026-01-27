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
}