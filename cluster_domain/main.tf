terraform {
  required_version = ">= 1.14"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.56"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0"
    }
  }
}

locals {
  ns_labels = {
    importance = "high"
    kind       = "system"
    app        = "external-dns"
  }
}

data "azurerm_client_config" "current" {}
