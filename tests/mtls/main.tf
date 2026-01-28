# =============================================================================
# mTLS Module Test Configuration
# =============================================================================
# This Terraform configuration tests the mTLS module in a local k3d cluster.
#
# Prerequisites:
#   - k3d cluster running (see setup.sh)
#   - cert-manager installed
#   - Traefik installed
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
# Traefik Namespace (mTLS-enabled)
# -----------------------------------------------------------------------------
# The traefik namespace is created by setup.sh (helm install traefik).
# We import it to add the mTLS label for trust-manager to sync the CA bundle.
# -----------------------------------------------------------------------------

resource "kubernetes_labels" "traefik_mtls" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "traefik"
  }
  labels = {
    (module.mtls.trust_bundle.namespace_label) = "true"
  }

  depends_on = [module.mtls]
}

# -----------------------------------------------------------------------------
# This creates the client certificate and CA bundle in the traefik namespace.
# -----------------------------------------------------------------------------

module "traefik_mtls" {
  source = "../../traefik_ingress/mtls_resources"

  mtls_config  = module.mtls.traefik_config
  namespace    = "traefik"
  service_name = "traefik"

  depends_on = [kubernetes_labels.traefik_mtls]
}

# -----------------------------------------------------------------------------
# Installs the traefik-options chart (TLS options, middlewares, etc.)
# -----------------------------------------------------------------------------

resource "helm_release" "traefik_options" {
  name      = "traefik-options"
  namespace = "traefik"
  chart     = "${path.module}/../../traefik_ingress/charts/traefik-options"

  depends_on = [module.traefik_mtls]
}

# -----------------------------------------------------------------------------
# This demonstrates the recommended pattern: each service defines its own
# ServersTransport with proper hostname verification (serverName).
#
# The ServersTransport must be in the same namespace as the secrets it
# references (traefik namespace), but can be used by IngressRoutes in
# other namespaces via cross-namespace reference.
# -----------------------------------------------------------------------------

resource "kubernetes_manifest" "mtls_server_transport" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "ServersTransport"
    metadata = {
      name      = "mtls-server-transport"
      namespace = "traefik" # TODO: Can't we really declary it in the project namespace?
    }
    spec = {
      # The serverName must match a SAN in the backend's certificate.
      # This enables proper TLS hostname verification.
      serverName = "mtls-server.mtls-test.svc.cluster.local"

      # Trust the internal CA for verifying backend server certificates
      rootCAsSecrets = [module.traefik_mtls.ca_bundle_secret_name]

      # Client certificate for Traefik to present to mTLS backends
      certificatesSecrets = [module.traefik_mtls.client_cert_secret_name]
    }
  }

  depends_on = [module.traefik_mtls]
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

output "traefik_mtls" {
  description = "Traefik mTLS resources"
  value = {
    client_cert_secret = module.traefik_mtls.client_cert_secret_name
    ca_bundle_secret   = module.traefik_mtls.ca_bundle_secret_name
  }
}
