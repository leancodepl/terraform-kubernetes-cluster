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
  version    = "6.11.2"

  namespace = kubernetes_namespace.external_dns.metadata[0].name

  dynamic "set" {
    for_each = local.external_dns_config
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [helm_release.external_dns_identity]
}


// We can't move to kubernetes_manifest - to apply a manifest we must know it's schema during plan
// phase. This means that the CRD (thus the content of this chart) needs to exists prior to
// the application and the cluster that we are planning on must also be available. This means that
// the `helm_release.external_dns_identity` resource needs to be applied _after_ the cluster is
// running, which requires two-pass `apply`. Having a chart bypasses this requirement (as Helm
// provider does not validate the resources up-front).
// Provider/TF bug to track: https://github.com/hashicorp/terraform-provider-kubernetes/issues/1782
resource "helm_release" "external_dns_identity" {
  name      = "external-dns-identity"
  namespace = kubernetes_namespace.external_dns.metadata[0].name
  chart     = "${path.module}/charts/external-dns-identity"

  set {
    name  = "identityName"
    value = local.external_dns_identity_name
  }
  set {
    name  = "userIdentityId"
    value = var.plugin.cluster_identity_id
  }
  set {
    name  = "userIdentityClientId"
    value = var.plugin.cluster_identity_client_id
  }
}

