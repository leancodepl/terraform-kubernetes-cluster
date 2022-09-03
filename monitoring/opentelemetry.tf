locals {
  default_opentelemetry_config = {
    exporters = {
      datadog = {
        api = {
          key = "$DATADOG_API_KEY"
        }
        host_metadata = {
          tags = [
            "env:${var.plugin.prefix}",
          ]
        }
      }
    }

    extensions = {
      health_check = {}
    }
    processors = {
      batch = {
        timeout = "10s"
      }
      k8sattributes = {
        passthrough = true
      }
      resourcedetection = {
        detectors = [
          "azure",
          "env",
        ]
        override = false
        timeout  = "5s"
      }
    }
    receivers = {
      otlp = {
        protocols = {
          grpc = {
            endpoint = "0.0.0.0:55680"
          }
          http = {
            endpoint = "0.0.0.0:55681"
          }
        }
      }
    }
    service = {
      extensions = ["health_check"]
      pipelines = {
        metrics = {
          exporters = ["datadog"]
          processors = [
            "resourcedetection",
            "k8sattributes",
            "batch",
          ]
          receivers = ["otlp"]
        },
        traces = {
          exporters = ["datadog"]
          processors = [
            "batch",
            "resourcedetection",
            "k8sattributes",
          ]
          receivers = ["otlp"]
        }
      }
    }
  }
}

resource "kubernetes_secret" "opentelemetry_config" {
  metadata {
    name      = "opentelemetry-config"
    namespace = kubernetes_namespace.main.metadata[0].name
    labels    = local.otel_labels
  }

  data = {
    agent_config    = yamlencode(var.opentelemetry_config == null ? local.default_opentelemetry_config : var.opentelemetry_config)
    datadog_api_key = var.datadog_keys.api
  }
}

resource "kubernetes_daemonset" "opentelemetry_collector" {
  metadata {
    name      = "opentelemetry-collector"
    namespace = kubernetes_namespace.main.metadata[0].name
    labels    = local.otel_labels
    annotations = {
      "config-hash" = sha256(kubernetes_secret.opentelemetry_config.data.agent_config)
    }
  }

  spec {
    selector {
      match_labels = {
        app       = "opentelemetry-collector"
        component = "agent"
      }
    }

    template {
      metadata {
        labels = {
          app       = "opentelemetry-collector"
          component = "agent"
        }
      }

      spec {
        volume {
          name = "config"
          secret {
            secret_name = kubernetes_secret.opentelemetry_config.metadata[0].name
            items {
              key  = "agent_config"
              path = "otel-agent-config.yaml"
            }
          }
        }

        container {
          name              = "agent"
          image             = var.opentelemetry_image
          image_pull_policy = "Always"

          args = ["--config", "/conf/otel-agent-config.yaml"]

          env {
            name = "DATADOG_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.opentelemetry_config.metadata[0].name
                key  = "datadog_api_key"
              }
            }
          }

          dynamic "port" {
            for_each = var.opentelemetry_ports

            content {
              host_port      = port.key
              container_port = port.key
            }
          }

          resources {
            limits = {
              cpu    = var.opentelemetry_resources.limits.cpu
              memory = var.opentelemetry_resources.limits.memory
            }

            requests = {
              cpu    = var.opentelemetry_resources.requests.cpu
              memory = var.opentelemetry_resources.requests.memory
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/conf"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "13133"
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "13133"
            }
          }
        }
      }
    }
  }
}
