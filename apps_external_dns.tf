resource "kubernetes_namespace" "external_dns" {
  count = var.deploy_external_dns ? 1 : 0

  metadata {
    name   = "external-dns"
    labels = local.ns_labels
  }
}

locals {
  external_dns_config = {
    "resources.requests.cpu"    = "10m",
    "resources.requests.memory" = "20Mi",
    "resources.limits.cpu"      = "100m",
    "resources.limits.memory"   = "50Mi",
    "sources[0]"                = "service",
    "sources[1]"                = "ingress",
    "provider"                  = "azure",
    "registry"                  = "txt",
    "txtOwnerId"                = "external-dns-${var.prefix}-k8s",
    "azure.tenantId"            = data.azurerm_client_config.current.tenant_id,
    "azure.subscriptionId"      = data.azurerm_client_config.current.subscription_id,
    "azure.resourceGroup"       = azurerm_resource_group.cluster.name,
    "azure.aadClientId"         = azuread_service_principal.service.application_id,

    "logFormat" = "json",
    "logLevel"  = "info",
  }
}

resource "helm_release" "external_dns" {
  count = var.deploy_external_dns ? 1 : 0

  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "4.0.0"

  namespace = kubernetes_namespace.external_dns[0].metadata[0].name

  set_sensitive {
    name  = "azure.aadClientSecret"
    value = random_password.service_secret.result
  }

  dynamic "set" {
    for_each = local.external_dns_config
    content {
      name  = set.key
      value = set.value
    }
  }
}
