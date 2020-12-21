locals {
  traefik_tags = {
    type = "internal"
    app  = "traefik-ingress"
  }
}

resource "kubernetes_namespace" "traefik" {
  metadata {
    name   = "traefik"
    labels = local.ns_labels
  }
}

resource "kubernetes_storage_class" "traefik_acme" {
  metadata {
    name = "traefik-acme"
  }
  storage_provisioner    = "kubernetes.io/azure-file"
  mount_options          = ["dir_mode=0777", "file_mode=0600", "uid=0", "gid=0"]
  allow_volume_expansion = false
  parameters = {
    skuName = "Standard_LRS"
  }
}

resource "azurerm_public_ip" "traefik_public_ip" {
  name                = "${var.prefix}-traefik-public-ip"
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location

  allocation_method = "Static"
  sku               = var.cluster_config.loadbalancer

  tags = local.tags
}

locals {
  traefik_args = concat([
    "--certificatesresolvers.le.acme.storage=/data/acme.json",
    "--certificatesresolvers.le.acme.httpChallenge",
    "--certificatesresolvers.le.acme.httpChallenge.entryPoint=web",
    "--certificatesresolvers.le.acme.email=jakub.fijalkowski@leancode.pl",
    "--certificatesresolvers.le.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory",
  ], var.traefik.args)
  traefik_config_forced = merge(var.traefik.config, {
    "image.tag"                                            = "2.3.4",
    "ingressRoute.dashboard.enabled"                       = false,
    "persistence.accessMode"                               = "ReadWriteMany",
    "persistence.enabled"                                  = true,
    "persistence.size"                                     = "1Gi",
    "persistence.storageClass"                             = kubernetes_storage_class.traefik_acme.metadata[0].name,
    "ports.web.redirectTo"                                 = "websecure",
    "ports.websecure.tls.enabled"                          = true,
    "ports.websecure.tls.certResolver"                     = "le",
    "providers.kubernetesIngress.publishedService.enabled" = true,

    "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group" = azurerm_resource_group.cluster.name,
    "service.spec.loadBalancerIP"                                                             = azurerm_public_ip.traefik_public_ip.ip_address,
  })
  traefik_config = merge({
    "resources.requests.cpu"    = "100m",
    "resources.requests.memory" = "50Mi",
    "resources.limits.cpu"      = "1",
    "resources.limits.memory"   = "256Mi",

    "logs.general.level"  = "INFO",
    "logs.access.enabled" = false,
    "logs.general.format" = "json",
  }, local.traefik_config_forced)
}

resource "helm_release" "traefik" {
  name = "traefik"

  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "9.11.0"

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

