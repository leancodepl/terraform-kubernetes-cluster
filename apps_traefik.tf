locals {
  traefik_excluded_fields = ["service.annotations", "ingressRoute.dashboard.enabled"]
  traefik_tags = {
    type = "internal"
    app  = "traefik-ingress"
  }
}

resource "kubernetes_manifest" "traefik_ns" {
  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "traefik"
    }
  }
}

resource "kubernetes_manifest" "traefik_configmap" {
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "traefik-ingress-config"
      namespace = kubernetes_manifest.traefik_ns.object.metadata.name
      labels    = local.traefik_tags
    }

    data = {
      "traefik.toml" = var.traefik.config_file == "" ? file("${path.module}/cfg/traefik.toml") : var.traefik.config_file
    }
  }
}

resource "kubernetes_manifest" "traefik_acme_storageclass" {
  manifest = {
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "traefik-acme"
    }
    storage_provisioner    = "kubernetes.io/azure-file"
    mount_options          = ["dir_mode=0777", "file_mode=0600", "uid=0", "gid=0"]
    allow_volume_expansion = false
    parameters = {
      skuName = "Standard_LRS"
    }
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

  namespace = kubernetes_manifest.traefik_ns.object.metadata.name

  set {
    name  = "additionalArguments[0]"
    value = "--certificatesresolvers.leresolver.acme.storage=/data/acme.json"
  }
  set {
    name  = "additionalArguments[1]"
    value = "--configFile=/config/traefik.toml"
  }
  set {
    name  = "ingressRoute.dashboard.enabled"
    value = false
  }
  set {
    name  = "service.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group"
    value = azurerm_resource_group.cluster.name
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
    name  = "volumes[0].type"
    value = "configMap"
  }
  set {
    name  = "volumes[0].name"
    value = kubernetes_manifest.traefik_configmap.object.metadata.name
  }
  set {
    name  = "volumes[0].mountPath"
    value = "/config"
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
    value = kubernetes_manifest.traefik_acme_storageclass.object.metadata.name
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

