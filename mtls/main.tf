# =============================================================================
# mTLS Infrastructure Module
# =============================================================================
# Provides cluster-wide mTLS infrastructure:
# - cert-manager CSI driver for secure certificate mounting
# - trust-manager for CA bundle distribution across namespaces
# - Internal PKI (self-signed CA and ClusterIssuer)
#
# Prerequisites:
# - cert-manager must be installed before this module
# =============================================================================

terraform {
  required_version = ">= 1.14"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1"
    }
  }
}

# Validate that cert-manager namespace exists (cert-manager must be installed)
data "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = var.cert_manager_namespace
  }
}

locals {
  cert_manager_ns = data.kubernetes_namespace_v1.cert_manager.metadata[0].name

  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "mtls-infrastructure"
  }
}
