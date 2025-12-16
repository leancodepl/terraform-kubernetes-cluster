locals {
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

    "azure.tenantId"                     = data.azurerm_client_config.current.tenant_id,
    "azure.subscriptionId"               = data.azurerm_client_config.current.subscription_id,
    "azure.resourceGroup"                = var.plugin.cluster_resource_group_name,
    "azure.useWorkloadIdentityExtension" = true,
  }

  # this has to be passed as yamlencoded `values` instead of `set` to preserve "true" as string, not boolean
  external_dns_config_workload_identity = {
    serviceAccount = {
      labels = {
        "azure.workload.identity/use" = "true"
      }
      annotations = {
        "azure.workload.identity/client-id" = var.plugin.cluster_identity_client_id
      }
    }
    podLabels = {
      "azure.workload.identity/use" = "true"
    }
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

resource "kubernetes_namespace_v1" "external_dns" {
  metadata {
    name   = "external-dns"
    labels = local.ns_labels
  }
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "8.3.7"

  namespace = kubernetes_namespace_v1.external_dns.metadata[0].name

  set = [
    for k, v in local.external_dns_config : {
      name  = k
      value = v
    }
  ]

  values = [yamlencode(local.external_dns_config_workload_identity)]

  depends_on = [azurerm_federated_identity_credential.identity_credential]
}

data "azurerm_kubernetes_cluster" "cluster" {
  name                = var.plugin.cluster_name
  resource_group_name = var.plugin.cluster_resource_group_name
}

resource "azurerm_federated_identity_credential" "identity_credential" {
  parent_id           = var.plugin.cluster_identity_id
  name                = "external-dns-access"
  resource_group_name = var.plugin.cluster_resource_group_name

  audience = ["api://AzureADTokenExchange"]
  subject  = "system:serviceaccount:${kubernetes_namespace_v1.external_dns.metadata[0].name}:external-dns"
  issuer   = data.azurerm_kubernetes_cluster.cluster.oidc_issuer_url
}