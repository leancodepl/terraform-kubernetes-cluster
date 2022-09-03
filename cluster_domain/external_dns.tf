locals {
  external_dns_identity_name = "external-dns-identity"

  external_dns_resources = {
    "resources.requests.cpu"    = var.resources.requests.cpu,
    "resources.requests.memory" = var.resources.requests.memory,
    "resources.limits.cpu"      = var.resources.limits.cpu,
    "resources.limits.memory"   = var.resources.limits.memory,
  }
  external_dns_config_aks = {
    "provider"   = "azure",
    "registry"   = "txt",
    "txtOwnerId" = "external-dns-${var.plugin.prefix}-k8s",

    "azure.tenantId"                    = data.azurerm_client_config.current.tenant_id,
    "azure.subscriptionId"              = data.azurerm_client_config.current.subscription_id,
    "azure.resourceGroup"               = var.plugin.cluster_resource_group_name,
    "azure.useManagedIdentityExtension" = true,

    "podLabels.aadpodidbinding" = local.external_dns_identity_name,
  }
  external_dns_config_basic = {
    "sources[0]" = "service",
    "sources[1]" = "ingress",

    "logFormat" = "json",
    "logLevel"  = "info",
  }
}

locals {
  external_dns_config = merge(local.external_dns_resources, local.external_dns_config_basic, var.config, local.external_dns_config_aks)
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name   = "external-dns"
    labels = local.ns_labels
  }
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
      name      = local.external_dns_identity_name
      namespace = kubernetes_namespace.external_dns.metadata[0].name
      labels    = local.ns_labels
      annotations = {
        "aadpodidentity.k8s.io/Behavior" = "namespaced"
      }
    }
    spec = {
      type       = 0
      resourceID = var.plugin.cluster_identity_id
      clientID   = var.plugin.cluster_identity_client_id
    }
  }

}

resource "kubernetes_manifest" "binding" {
  manifest = {
    apiVersion = "aadpodidentity.k8s.io/v1"
    kind       = "AzureIdentityBinding"
    metadata = {
      name      = "${local.external_dns_identity_name}-binding"
      namespace = kubernetes_namespace.external_dns.metadata[0].name
      labels    = local.ns_labels
    }
    spec = {
      azureIdentity = local.external_dns_identity_name
      selector      = local.external_dns_identity_name
    }
  }
}
