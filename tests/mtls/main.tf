# =============================================================================
# mTLS Module Test Configuration
# =============================================================================
# This Terraform configuration tests the mTLS module in a local k3d cluster.
#
# Prerequisites:
#   - k3d cluster running (see setup.sh)
#   - cert-manager installed
#
# Usage:
#   terraform init
#   terraform apply -auto-approve
# =============================================================================

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration (uses current kubeconfig context)
# -----------------------------------------------------------------------------

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

# -----------------------------------------------------------------------------
# mTLS Module Under Test
# -----------------------------------------------------------------------------

module "mtls" {
  source = "../../mtls"

  cert_manager_namespace = var.cert_manager_namespace
  helm_versions          = var.helm_versions
  internal_ca            = var.internal_ca
  trust_bundle           = var.trust_bundle
}

# -----------------------------------------------------------------------------
# Test Namespace (mTLS-enabled)
# -----------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "test" {
  metadata {
    name = "mtls-test"
    labels = {
      (module.mtls.trust_bundle.namespace_label) = "true"
    }
  }

  depends_on = [module.mtls]
}

# -----------------------------------------------------------------------------
# Outputs for Verification
# -----------------------------------------------------------------------------

output "issuer" {
  description = "Internal CA ClusterIssuer configuration"
  value       = module.mtls.issuer
}

output "root_ca" {
  description = "Root CA Secret configuration"
  value       = module.mtls.root_ca
}

output "trust_bundle" {
  description = "Trust bundle configuration"
  value       = module.mtls.trust_bundle
}

output "traefik_config" {
  description = "Complete mTLS configuration for traefik_ingress module"
  value       = module.mtls.traefik_config
}

output "test_namespace" {
  description = "Test namespace name"
  value       = kubernetes_namespace_v1.test.metadata[0].name
}
