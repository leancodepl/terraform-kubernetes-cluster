locals {
  use_lets_encrypt = var.acme_mail != null

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
    "persistence.storageClass"                             = kubernetes_storage_class_v1.traefik_acme.metadata[0].name,
    "ports.web.redirections.entryPoint.to"                 = "websecure",
    "ports.web.redirections.entryPoint.scheme"             = "https",
    "ports.web.redirections.entryPoint.permanent"          = true,
    "providers.kubernetesIngress.publishedService.enabled" = true,

    "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group" = var.plugin.cluster_resource_group_name,
    "service.spec.loadBalancerIP"                                                             = azurerm_public_ip.traefik_public_ip.ip_address,
  }

  traefik_config_monitoring = var.enable_monitoring ? {
    "env[0].name"                         = "AGENT_HOST_IP",
    "env[0].valueFrom.fieldRef.fieldPath" = "status.hostIP",
  } : {}

  traefik_config_logging = {
    "logs.general.level"  = "INFO",
    "logs.access.enabled" = false,
    "logs.general.format" = "json",
  }

  traefik_config_tls = local.use_lets_encrypt ? {
    "ports.websecure.tls.enabled"      = true,
    "ports.websecure.tls.certResolver" = "le"
    } : {
    "ports.websecure.tls.enabled" = true,
  }
}

locals {
  traefik_config = merge(
    local.traefik_resources,
    local.traefik_config_logging,
    local.traefik_config_aks,
    local.traefik_config_monitoring,
    local.traefik_config_tls,
    var.traefik_config
  )

  traefik_monitoring_args = var.enable_monitoring ? [
    "--tracing.otlp=true",
    "--tracing.otlp.grpc=true",
    "--tracing.otlp.grpc.insecure=true",
    "--tracing.otlp.grpc.endpoint=$(AGENT_HOST_IP):55680",
    "--metrics.otlp=true",
    "--metrics.otlp.grpc=true",
    "--metrics.otlp.grpc.insecure=true",
    "--metrics.otlp.grpc.endpoint=$(AGENT_HOST_IP):55680",
  ] : []

  traefik_le_args = local.use_lets_encrypt ? [
    "--certificatesresolvers.le.acme.storage=/data/acme.json",
    "--certificatesresolvers.le.acme.httpChallenge",
    "--certificatesresolvers.le.acme.httpChallenge.entryPoint=web",
    "--certificatesresolvers.le.acme.email=${var.acme_mail}",
    "--certificatesresolvers.le.acme.caserver=https://acme-v02.api.letsencrypt.org/directory",
  ] : []

  traefik_args = concat([
    "--entrypoints.websecure.http.middlewares=${kubernetes_namespace_v1.traefik.metadata[0].name}-sts-header@kubernetescrd",
    "--core.defaultRuleSyntax=${var.default_router_rule_syntax}",
  ], local.traefik_le_args, local.traefik_monitoring_args)
}

resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = "traefik"
    labels = merge(local.ns_labels, var.ambient_mesh_enabled ? {
      "istio.io/dataplane-mode" = "ambient"
    } : {})
  }
}

resource "helm_release" "traefik" {
  name = "traefik"

  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "37.4.0"

  namespace = kubernetes_namespace_v1.traefik.metadata[0].name

  set = concat(
    [
      for key, value in local.traefik_config : {
        name  = key
        value = value
      }
    ],
    [
      for index, value in local.traefik_args : {
        name  = "additionalArguments[${index}]"
        value = value
      }
    ]
  )
}

// We can't move to kubernetes_manifest - to apply a manifest we must know it's schema during plan
// phase. This means that the CRD (thus the content of this chart) needs to exists prior to
// the application. This means that the `helm_release.traefik` resource needs to be applied _before_
// the options - which would require two-pass `apply`. Having a chart bypasses this requirement (as
// Helm provider does not validate the resources).
// Provider/TF bug to track: https://github.com/hashicorp/terraform-provider-kubernetes/issues/1782
resource "helm_release" "traefik_options" {
  name      = "traefik-options"
  namespace = kubernetes_namespace_v1.traefik.metadata[0].name
  chart     = "${path.module}/charts/traefik-options"

  depends_on = [helm_release.traefik]
}
