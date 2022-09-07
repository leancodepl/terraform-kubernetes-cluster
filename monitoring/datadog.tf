locals {
  datadog_resources = {
    "agents.containers.agent.resources.requests.cpu"    = var.datadog_resources.requests.cpu,
    "agents.containers.agent.resources.requests.memory" = var.datadog_resources.requests.memory,
    "agents.containers.agent.resources.limits.cpu"      = var.datadog_resources.limits.cpu,
    "agents.containers.agent.resources.limits.memory"   = var.datadog_resources.limits.memory,

    "agents.containers.processAgent.resources.requests.cpu"    = var.datadog_resources.requests.cpu,
    "agents.containers.processAgent.resources.requests.memory" = var.datadog_resources.requests.memory,
    "agents.containers.processAgent.resources.limits.cpu"      = var.datadog_resources.limits.cpu,
    "agents.containers.processAgent.resources.limits.memory"   = var.datadog_resources.limits.memory,

    "agents.containers.traceAgent.resources.requests.cpu"    = var.datadog_resources.requests.cpu,
    "agents.containers.traceAgent.resources.requests.memory" = var.datadog_resources.requests.memory,
    "agents.containers.traceAgent.resources.limits.cpu"      = var.datadog_resources.limits.cpu,
    "agents.containers.traceAgent.resources.limits.memory"   = var.datadog_resources.limits.memory,
  }
  datadog_features = {
    "datadog.otlp.receiver.protocols.grpc.enabled"  = true,
    "datadog.otlp.receiver.protocols.grpc.endpoint" = "0.0.0.0:55680",
    "datadog.otlp.receiver.protocols.http.enabled"  = true,
    "datadog.otlp.receiver.protocols.http.endpoint" = "0.0.0.0:55681",
  }
  datadog_aks = {
    # See for an explanation: https://docs.datadoghq.com/containers/kubernetes/distributions/?tab=helm#AKS
    "datadog.kubelet.host.valueFrom.fieldRef.fieldPath" = "spec.nodeName"
    "datadog.kubelet.hostCAPath"                        = "/etc/kubernetes/certs/kubeletserver.crt"
    "datadog.kubelet.tlsVerify"                         = false

    # As of AKS 1.19, containerd is the default runtime and we can disable Docker
    "datadog.criSocketPath" = "/var/run/containerd/containerd.sock",
  }
}

locals {
  datadog_config = merge(local.datadog_resources, local.datadog_features, var.datadog_config, local.datadog_aks)
}

# See: https://github.com/DataDog/helm-charts/tree/master/charts/datadog
resource "helm_release" "datadog_agent" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = "3.0.0"

  namespace = kubernetes_namespace.main.metadata[0].name

  set_sensitive {
    name  = "datadog.apiKey"
    value = var.datadog_keys.api
  }

  set_sensitive {
    name  = "datadog.appKey"
    value = var.datadog_keys.app
  }

  dynamic "set" {
    for_each = local.datadog_config
    content {
      name  = set.key
      value = set.value
    }
  }

  dynamic "set" {
    for_each = local.datadog_labels
    content {
      name  = "commonLabels.${set.key}"
      value = set.value
    }
  }
}
