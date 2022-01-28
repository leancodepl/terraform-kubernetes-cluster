locals {
  otel_tags = merge(local.ns_labels, {
    app = "opentelemetry-collector",
  })
}

resource "kubernetes_namespace" "otel" {
  count = var.deploy_opentelemetry_collector ? 1 : 0

  metadata {
    name   = "opentelemetry"
    labels = local.otel_tags
  }
}

resource "kubernetes_secret" "otel_config" {
  count = var.deploy_opentelemetry_collector ? 1 : 0

  metadata {
    name      = "otel-config"
    namespace = kubernetes_namespace.otel[0].metadata[0].name
    labels    = local.otel_tags
  }

  data = {
    "otel-agent-config.yaml" = yamlencode({
      exporters = {
        datadog = {
          api = {
            key = var.datadog.secret
          }
          env = var.prefix
          tags = [
            "env:${var.prefix}",
          ]
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
          ballast_size_mib = var.opentelemetry.limiter.ballast_size_mib
          check_interval   = "5s"
          limit_mib        = var.opentelemetry.limiter.limit_mib
          spike_limit_mib  = var.opentelemetry.limiter.spike_limit_mib
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
              "memory_limiter",
              "resourcedetection",
              "k8sattributes",
              "batch",
            ]
            receivers = ["otlp"]
          },
          traces = {
            exporters = ["datadog"]
            processors = [
              "memory_limiter",
              "batch",
              "resourcedetection",
              "k8sattributes",
            ]
            receivers = ["otlp"]
          }
        }
      }
    })
  }
}

resource "kubernetes_daemonset" "otel_agent" {
  count = var.deploy_opentelemetry_collector ? 1 : 0

  metadata {
    name      = "otel-agent"
    namespace = kubernetes_namespace.otel[0].metadata[0].name
    labels    = local.otel_tags
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
            secret_name = kubernetes_secret.otel_config[0].metadata[0].name
          }
        }

        container {
          name              = "agent"
          image             = var.opentelemetry.image
          image_pull_policy = "Always"

          command = [
            "/otelcol",
            "--config=/conf/otel-agent-config.yaml",
          ]

          port {
            host_port      = 55680
            container_port = 55680
          }

          port {
            host_port      = 55681
            container_port = 55681
          }

          resources {
            limits = {
              cpu    = var.opentelemetry.resources.limits.cpu
              memory = var.opentelemetry.resources.limits.memory
            }

            requests = {
              cpu    = var.opentelemetry.resources.requests.cpu
              memory = var.opentelemetry.resources.requests.memory
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

        dynamic "toleration" {
          for_each = var.opentelemetry.tolerations

          content {
            key      = toleration.value.key
            operator = toleration.value.operator
            value    = toleration.value.value
            effect   = toleration.value.effect
          }
        }
      }
    }
  }
}
