locals {
  default_opentelemetry_config = {
    exporters = {
      otlp = {
        endpoint = "$${HOST_IP}:55680"
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
      memory_limiter = {
        check_interval         = "5s"
        limit_percentage       = 50
        spike_limit_percentage = 25
      }
      resourcedetection = {
        detectors = [
          "azure",
          "aks",
        ]
        override = false
        timeout  = "5s"
      }
    }
    receivers = {
      jaeger = {
        protocols = {
          thrift_http = {
            endpoint = "0.0.0.0:14268"
          }
        }
      }
    }
    service = {
      extensions = ["health_check"]
      telemetry = {
        logs = {
          encoding = "json"
        }
      }
      pipelines = {
        traces = {
          exporters = ["otlp"]
          processors = [
            "memory_limiter",
            "batch",
            "resourcedetection",
            "k8sattributes",
          ]
          receivers = ["jaeger"]
        }
      }
    }
  }
}

resource "kubernetes_config_map" "opentelemetry_config" {
  metadata {
    name      = "opentelemetry-config"
    namespace = kubernetes_namespace.main.metadata[0].name
    labels    = local.otel_labels
  }

  data = {
    agent_config = var.opentelemetry_config == null ? yamlencode(local.default_opentelemetry_config) : var.opentelemetry_config
  }
}

resource "kubernetes_deployment_v1" "opentelemetry_collector" {
  metadata {
    name      = "opentelemetry-collector"
    namespace = kubernetes_namespace.main.metadata[0].name
    labels    = local.otel_labels
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
        annotations = {
          "config-hash" = sha256(kubernetes_config_map.opentelemetry_config.data.agent_config)
        }
      }

      spec {
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.opentelemetry_config.metadata[0].name
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

resource "kubernetes_service_v1" "opentelemetry_service" {
  metadata {
    name      = "opentelemetry-svc"
    namespace = kubernetes_namespace.main.metadata[0].name
    labels    = local.otel_labels
  }

  spec {
    selector = {
      app       = "opentelemetry-collector"
      component = "agent"
    }

    port {
      port        = 14268
      target_port = 14268
    }

    type = "ClusterIP"
  }
}
