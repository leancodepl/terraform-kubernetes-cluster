locals {
  traefik_excluded_fields = ["service.annotations", "ingressRoute.dashboard.enabled"]
  traefik_tags = {
    type = "internal"
    app  = "traefik-ingress"
  }
}

resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
  }
}

resource "kubernetes_config_map" "traefik_config" {
  metadata {
    name      = "traefik-ingress-config"
    namespace = kubernetes_namespace.traefik.metadata[0].name
    labels    = local.traefik_tags
  }

  data = {
    "traefik.toml" = var.traefik.config_file
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

resource "helm_release" "traefik" {
  name = "traefik"

  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "9.9.0"

  namespace = kubernetes_namespace.traefik.metadata[0].name

  set {
    name = "additionalArguments"
    value = [
      "--configFile=/config/traefik.toml",
      "--certificatesresolvers.leresolver.acme.storage=/data/acme.json"
    ]
  }
  set {
    name  = "ingressRoute.dashboard.enabled"
    value = false
  }
  set {
    name = "service.annotations"
    value = {
      "service.beta.kubernetes.io/azure-load-balancer-resource-group" = azurerm_resource_group.cluster.name
    }
  }
  set {
    name  = "ports.web.redirectTo"
    value = "websecure"
  }
  set {
    name  = "ports.websecure.tls.enabled"
    value = true
  }
  set {
    name  = "ports.websecure.tls.certResolver"
    value = "leresolver"
  }
  set {
    name = "volumes"
    value = [
      {
        type      = "configMap"
        name      = kubernetes_config_map.kubernetes_config_map.traefik_config.metadata[0].name
        mountPath = "/config"
      }
    ]
  }
  set {
    name  = "persistence.enabled"
    value = true
  }
  set {
    name  = "persistence.accessMode"
    value = "ReadWriteMany"
  }
  set {
    name  = "persistence.storageClass"
    value = kubernetes_storage_class.traefik_acme.metadata[0].name
  }
  set {
    name  = "persistence.size"
    value = "1Gi"
  }

  dynamic "set" {
    for_each = { for k, v in var.traefik.config : k => v if ! contains(local.traefik_excluded_fields, k) }
    content {
      name  = set.key
      value = set.value
    }
  }
}

