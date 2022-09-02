locals {
  traefik_args = concat([
    "--certificatesresolvers.le.acme.storage=/data/acme.json",
    "--certificatesresolvers.le.acme.httpChallenge",
    "--certificatesresolvers.le.acme.httpChallenge.entryPoint=web",
    "--certificatesresolvers.le.acme.email=${var.acme_mail}",
    "--certificatesresolvers.le.acme.caserver=https://acme-v02.api.letsencrypt.org/directory",
    "--entrypoints.websecure.http.middlewares=${kubernetes_namespace.traefik.metadata[0].name}-sts-header@kubernetescrd",
  ], var.args)
  traefik_config_forced = merge(var.config, {
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
  })
  traefik_config = merge({
    "resources.requests.cpu"    = var.resources.requests.cpu,
    "resources.requests.memory" = var.resources.requests.memory,
    "resources.limits.cpu"      = var.resources.limits.cpu,
    "resources.limits.memory"   = var.resources.limits.memory,

    "logs.general.level"  = "INFO",
    "logs.access.enabled" = false,
    "logs.general.format" = "json",
  }, local.traefik_config_forced)
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
  version    = "10.24.1"

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

resource "helm_release" "traefik_options" {
  name      = "traefik-options"
  namespace = kubernetes_namespace.traefik.metadata[0].name
  chart     = "${path.module}/charts/traefik-options"

  depends_on = [helm_release.traefik]
}

resource "kubernetes_manifest" "sts_header" {
  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name = "sts-header"
    }
    spec = {
      headers = {
        stsSeconds           = 31536000
        stsIncludeSubdomains = true
        stsPreload           = true
      }
    }
  }

  depends_on = [helm_release.traefik]
}

resource "kubernetes_manifest" "tls_options" {
  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "TLSOption"
    metadata = {
      name   = "default"
      labels = local.ns_labels
    }
    spec = {
      minVersion = "VersionTLS12"
      cipherSuites = [
        "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
        "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
        "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
        "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
      ]
    }
  }

  depends_on = [helm_release.traefik]
}
