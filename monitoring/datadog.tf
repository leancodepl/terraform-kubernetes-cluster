locals {
  datadog_resources = {
    "agents.containers.agent.resources.requests.cpu"    = var.datadog_resources.requests.cpu
    "agents.containers.agent.resources.requests.memory" = var.datadog_resources.requests.memory
    "agents.containers.agent.resources.limits.cpu"      = var.datadog_resources.limits.cpu
    "agents.containers.agent.resources.limits.memory"   = var.datadog_resources.limits.memory

    "agents.containers.processAgent.resources.requests.cpu"    = var.datadog_resources.requests.cpu
    "agents.containers.processAgent.resources.requests.memory" = var.datadog_resources.requests.memory
    "agents.containers.processAgent.resources.limits.cpu"      = var.datadog_resources.limits.cpu
    "agents.containers.processAgent.resources.limits.memory"   = var.datadog_resources.limits.memory

    "agents.containers.traceAgent.resources.requests.cpu"    = var.datadog_resources.requests.cpu
    "agents.containers.traceAgent.resources.requests.memory" = var.datadog_resources.requests.memory
    "agents.containers.traceAgent.resources.limits.cpu"      = var.datadog_resources.limits.cpu
    "agents.containers.traceAgent.resources.limits.memory"   = var.datadog_resources.limits.memory

    "agents.priorityClassName" = "system-cluster-critical"
  }
  datadog_features = {
    "datadog.otlp.receiver.protocols.grpc.enabled"  = true,
    "datadog.otlp.receiver.protocols.grpc.endpoint" = "0.0.0.0:55680",
    "datadog.otlp.receiver.protocols.http.enabled"  = true,
    "datadog.otlp.receiver.protocols.http.endpoint" = "0.0.0.0:55681",

    "datadog.checksCardinality"        = "orchestrator",
    "datadog.dogstatsd.tagCardinality" = "orchestrator",
  }
  datadog_aks = {
    "datadog.kubelet.tlsVerify" = false

    "datadog.tags[0]" = "env:${var.plugin.prefix}"

    # As of AKS 1.19, containerd is the default runtime and we can disable Docker
    "datadog.criSocketPath" = "/var/run/containerd/containerd.sock",
  }
  datadog_ignores = {
    "DD_APM_IGNORE_RESOURCES"   = join(",", [for x in var.datadog_apm_ignore.by_resouce : "\"${x}\""])
    "DD_APM_FILTER_TAGS_REJECT" = join(" ", var.datadog_apm_ignore.by_tag)
  }
  datadog_env = merge(var.datadog_env, local.datadog_ignores)
}

locals {
  datadog_config = merge(local.datadog_resources, local.datadog_features, local.datadog_aks, var.datadog_config)
}

resource "kubernetes_secret_v1" "datadog_keys" {
  metadata {
    name      = "datadog-keys"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  data = {
    # Do not change, following key names are required by the Datadog Helm chart.
    api-key = var.datadog_keys.api
    app-key = var.datadog_keys.app
  }
}

# See: https://github.com/DataDog/helm-charts/tree/main/charts/datadog
resource "helm_release" "datadog_agent" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = var.datadog_chart_version

  namespace = kubernetes_namespace_v1.main.metadata[0].name

  set = concat(
    [
      {
        name  = "datadog.apiKeyExistingSecret"
        value = kubernetes_secret_v1.datadog_keys.metadata[0].name
      },
      {
        name  = "datadog.appKeyExistingSecret"
        value = kubernetes_secret_v1.datadog_keys.metadata[0].name
      },
    ],
    [
      for k, v in local.datadog_config : {
        name  = k
        value = v
      }
    ],
    [
      for k, v in local.datadog_labels : {
        name  = "commonLabels.${k}"
        value = v
      }
    ]
  )

  values = [
    yamlencode({
      "datadog" = {
        "envDict" = local.datadog_env
      }
    })
  ]
}
