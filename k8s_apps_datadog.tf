locals {
  datadog_agent_tags = {
    type = "internal"
    app  = "datadog-agent"
  }
  datadog_agent_daemonset_tags = merge(local.datadog_agent_tags, { component = "daemonset" })
  datadog_shared_config = {
    KUBERNETES                           = "true"
    DD_COLLECT_KUBERNETES_EVENTS         = "true"
    DD_LEADER_ELECTION                   = "true"
    DD_APM_ENABLED                       = "false"
    DD_PROCESS_AGENT_ENABLED             = "true"
    DD_KUBE_RESOURCES_NAMESPACE          = "kube-system"
    DD_LOGS_ENABLED                      = "true"
    DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL = "true"
  }
}

resource "kubernetes_service_account" "datadog_agent" {
  metadata {
    name      = "datadog-agent"
    namespace = "kube-system"

    labels = local.datadog_agent_tags
  }
}

resource "kubernetes_cluster_role" "datadog_agent" {
  metadata {
    name   = "datadog-agent"
    labels = local.datadog_agent_tags
  }

  rule {
    api_groups = [""]
    resources  = ["services", "events", "endpoints", "pods", "nodes", "componentstatuses"]
    verbs      = ["get", "watch", "list"]
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create"]
  }
  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["datadogtoken", "datadog-leader-election"]
    verbs          = ["get", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes/metrics", "nodes/spec", "nodes/proxy", "nodes/stats"]
    verbs      = ["get"]
  }
  rule {
    non_resource_urls = ["/version", "/healthz", "/metrics"]
    verbs             = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "datadog_agent" {
  metadata {
    name   = "datadog-agent-access"
    labels = local.datadog_agent_tags
  }
  role_ref {
    kind      = "ClusterRole"
    api_group = "rbac.authorization.k8s.io"
    name      = kubernetes_cluster_role.datadog_agent.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.datadog_agent.metadata[0].name
    namespace = kubernetes_service_account.datadog_agent.metadata[0].namespace
  }
}

resource "kubernetes_secret" "datadog_secret" {
  metadata {
    name      = "datadog-agent-secret"
    namespace = "kube-system"
    labels    = local.datadog_agent_tags
  }

  type = "Opaque"
  data = {
    api_key = var.datadog.secret
  }
}

resource "kubernetes_secret" "datadog_additional_config" {
  metadata {
    name      = "datadog-additional-config"
    namespace = "kube-system"
    labels    = local.datadog_agent_tags
  }

  type = "Opaque"
  data = var.datadog_additional_config
}

resource "kubernetes_daemonset" "datadog_agent" {
  metadata {
    name      = "datadog-agent"
    namespace = "kube-system"
    labels    = local.datadog_agent_tags
  }

  spec {
    selector {
      match_labels = local.datadog_agent_daemonset_tags
    }

    template {
      metadata {
        name   = "datadog-agent"
        labels = local.datadog_agent_daemonset_tags
      }

      spec {
        service_account_name            = kubernetes_service_account.datadog_agent.metadata[0].name
        automount_service_account_token = true

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.azure.com/cluster"
                  operator = "Exists"
                }
              }
            }
          }
        }

        toleration {
          operator = "Exists"
        }

        volume {
          name = "dockersocket"
          host_path {
            path = "/var/run/docker.sock"
          }
        }
        volume {
          name = "procdir"
          host_path {
            path = "/proc"
          }
        }
        volume {
          name = "cgroups"
          host_path {
            path = "/sys/fs/cgroup"
          }
        }
        volume {
          name = "pointdir"
          host_path {
            path = "/opt/datadog-agent/run"
          }
        }
        volume {
          name = "logpodpath"
          host_path {
            path = "/var/log/pods"
          }
        }
        volume {
          name = "logcontainerpath"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }
        volume {
          name = "additionalconfig"
          secret {
            secret_name = kubernetes_secret.datadog_additional_config.metadata[0].name
            dynamic "items" {
              for_each = var.datadog_additional_config
              content {
                key  = items.key
                path = replace(items.key, "--", "/")
              }
            }
          }
        }

        container {
          name              = "agent"
          image             = "datadog/agent:latest"
          image_pull_policy = "Always"

          port {
            name           = "dogstatsdport"
            protocol       = "UDP"
            container_port = 8125
            host_port      = 8125
          }
          port {
            name           = "traceport"
            protocol       = "TCP"
            container_port = 8126
            host_port      = 8126
          }

          resources {
            requests {
              memory = "300Mi"
              cpu    = "200m"
            }
            limits {
              memory = "300Mi"
              cpu    = "200m"
            }
          }

          volume_mount {
            name       = "dockersocket"
            mount_path = "/host/var/run/docker.sock"
          }
          volume_mount {
            name       = "procdir"
            mount_path = "/host/proc"
            read_only  = true
          }
          volume_mount {
            name       = "cgroups"
            mount_path = "/host/sys/fs/cgroup"
            read_only  = true
          }
          volume_mount {
            name       = "pointdir"
            mount_path = "/opt/datadog-agent/run"
          }
          volume_mount {
            name       = "logpodpath"
            mount_path = "/var/log/pods"
          }
          volume_mount {
            name       = "logcontainerpath"
            mount_path = "/var/lib/docker/containers"
          }
          volume_mount {
            name       = "additionalconfig"
            mount_path = "/conf.d"
            read_only  = true
          }

          liveness_probe {
            exec {
              command = ["./probe.sh"]
            }
            initial_delay_seconds = 15
            period_seconds        = 5
          }

          env {
            name = "DD_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.datadog_secret.metadata[0].name
                key  = "api_key"
              }
            }
          }
          env {
            name = "DD_KUBERNETES_KUBELET_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }
          dynamic "env" {
            for_each = merge(local.datadog_shared_config, var.datadog.config)
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
}
