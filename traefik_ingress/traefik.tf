locals {
  traefik_resources = {
    "resources.requests.cpu"    = var.resources.requests.cpu,
    "resources.requests.memory" = var.resources.requests.memory,
    "resources.limits.cpu"      = var.resources.limits.cpu,
    "resources.limits.memory"   = var.resources.limits.memory,
  }
  traefik_config_aks = {
    "ingressRoute.dashboard.enabled"                       = false,
    "persistence.accessMode"                               = "ReadWriteMany",
    "persistence.enabled"                                  = true,
    "persistence.size"                                     = "1Gi",
    "persistence.storageClass"                             = kubernetes_storage_class.traefik_acme.metadata[0].name,
    "ports.web.redirectTo"                                 = "websecure",
    "ports.websecure.tls.enabled"                          = true,
    "ports.websecure.tls.certResolver"                     = "le",
    "providers.kubernetesIngress.publishedService.enabled" = true,

    "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group" = var.plugin.cluster_resource_group_name,
    "service.spec.loadBalancerIP"                                                             = azurerm_public_ip.traefik_public_ip.ip_address,
  }
  traefik_config_logging = {
    "logs.general.level"  = "INFO",
    "logs.access.enabled" = false,
    "logs.general.format" = "json",
  }
}

locals {
  traefik_config = merge(local.traefik_resources, local.traefik_config_logging, var.config, local.traefik_config_aks)

  traefik_args = concat([
    "--certificatesresolvers.le.acme.storage=/data/acme.json",
    "--certificatesresolvers.le.acme.httpChallenge",
    "--certificatesresolvers.le.acme.httpChallenge.entryPoint=web",
    "--certificatesresolvers.le.acme.email=${var.acme_mail}",
    "--certificatesresolvers.le.acme.caserver=https://acme-v02.api.letsencrypt.org/directory",
    "--entrypoints.websecure.http.middlewares=${kubernetes_namespace.traefik.metadata[0].name}-sts-header@kubernetescrd",
  ], var.args)
}

resource "kubernetes_namespace" "traefik" {
  metadata {
    name   = "traefik"
    labels = local.ns_labels
  }
}

resource "helm_release" "traefik" {
  name = "traefik"

  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "21.1.0"

  namespace = kubernetes_namespace.traefik.metadata[0].name

  dynamic "set" {
    for_each = local.traefik_config
    content {
      name  = set.key
      value = set.value
    }
  }

  dynamic "set" {
    for_each = { for i, v in local.traefik_args : i => v }
    content {
      name  = "additionalArguments[${set.key}]"
      value = set.value
    }
  }
}

// We can't move to kubernetes_manifest - to apply a manifest we must know it's schema during plan
// phase. This means that the CRD (thus the content of this chart) needs to exists prior to
// the application. This means that the `helm_release.traefik` resource needs to be applied _before_
// the options - which would require two-pass `apply`. Having a chart bypasses this requirement (as
// Helm provider does not validate the resources).
// Provider/TF bug to track: https://github.com/hashicorp/terraform-provider-kubernetes/issues/1782
resource "helm_release" "traefik_options" {
  name      = "traefik-options"
  namespace = kubernetes_namespace.traefik.metadata[0].name
  chart     = "${path.module}/charts/traefik-options"

  depends_on = [helm_release.traefik]
}

