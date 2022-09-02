resource "kubernetes_namespace" "external_dns" {
  metadata {
    name   = "external-dns"
    labels = local.ns_labels
  }
}

locals {
  external_dns_identity_name = "external-dns-identity"

  external_dns_config = merge(var.config, {
    "resources.requests.cpu"    = var.resources.requests.cpu,
    "resources.requests.memory" = var.resources.requests.memory,
    "resources.limits.cpu"      = var.resources.limits.cpu,
    "resources.limits.memory"   = var.resources.limits.memory,

    "sources[0]" = "service",
    "sources[1]" = "ingress",

    "provider"   = "azure",
    "registry"   = "txt",
    "txtOwnerId" = "external-dns-${var.plugin.prefix}-k8s",

    "azure.tenantId"                    = data.azurerm_client_config.current.tenant_id,
    "azure.subscriptionId"              = data.azurerm_client_config.current.subscription_id,
    "azure.resourceGroup"               = var.plugin.cluster_resource_group_name,
    "azure.useManagedIdentityExtension" = true,

    "podLabels.aadpodidbinding" = local.external_dns_identity_name,

    "logFormat" = "json",
    "logLevel"  = "info",
  })
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "6.8.1"

  namespace = kubernetes_namespace.external_dns.metadata[0].name

  dynamic "set" {
    for_each = local.external_dns_config
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [kubernetes_manifest.identity, kubernetes_manifest.binding]
}

resource "kubernetes_manifest" "identity" {
  manifest = {
    apiVersion = "aadpodidentity.k8s.io/v1"
    kind       = "AzureIdentity"
    metadata = {
      name = local.external_dns_identity_name
      annotations = {
        "aadpodidentity.k8s.io/Behavior" = "namespaced"
      }
      labels = local.ns_labels
      spec = {
        type       = 0
        resourceID = var.plugin.cluster_identity_id
        clientID   = var.plugin.cluster_identity_client_id
      }
    }
  }

}

resource "kubernetes_manifest" "binding" {
  manifest = {
    apiVersion = "aadpodidentity.k8s.io/v1"
    kind       = "AzureIdentityBinding"
    metadata = {
      name   = "${local.external_dns_identity_name}-binding"
      labels = local.ns_labels
      spec = {
        azureIdentity = local.external_dns_identity_name
        selector      = local.external_dns_identity_name
      }
    }
  }
}
