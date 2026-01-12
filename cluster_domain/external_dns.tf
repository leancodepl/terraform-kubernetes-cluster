locals {
  azure_config = {
    json = jsonencode({
      tenantId                    = data.azurerm_client_config.current.tenant_id
      subscriptionId              = data.azurerm_client_config.current.subscription_id
      resourceGroup               = var.plugin.cluster_resource_group_name
      useWorkloadIdentityExtension = true
    })
    secret_name = "azure-config"
    volume_name = "azure-config"
  }

  external_dns_config = {
    resources = {
      requests = {
        cpu    = var.resources.requests.cpu
        memory = var.resources.requests.memory
      }
      limits = {
        cpu    = var.resources.limits.cpu
        memory = var.resources.limits.memory
      }
    }

    provider   = "azure"
    registry   = "txt"
    txtOwnerId = "external-dns-${var.plugin.prefix}-k8s"

    sources = ["service", "ingress"]

    logFormat = "json"
    logLevel  = "info"

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

    extraVolumes = [
      {
        name = local.azure_config.volume_name
        secret = {
          secretName = local.azure_config.secret_name
        }
      }
    ]

    extraVolumeMounts = [
      {
        name      = local.azure_config.volume_name
        mountPath = "/etc/kubernetes"
        readOnly  = true
      }
    ]
  }

  external_dns_values = merge(local.external_dns_config, var.config)
}

resource "kubernetes_namespace_v1" "external_dns" {
  metadata {
    name   = "external-dns"
    labels = local.ns_labels
  }
}

resource "kubernetes_secret_v1" "external_dns_azure_config" {
  metadata {
    name      = local.azure_config.secret_name
    namespace = kubernetes_namespace_v1.external_dns.metadata[0].name
  }

  data = {
    "azure.json" = local.azure_config.json
  }
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.19.0"

  namespace = kubernetes_namespace_v1.external_dns.metadata[0].name

  values = [yamlencode(local.external_dns_values)]

  depends_on = [
    azurerm_federated_identity_credential.identity_credential,
    kubernetes_secret_v1.external_dns_azure_config,
  ]
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
