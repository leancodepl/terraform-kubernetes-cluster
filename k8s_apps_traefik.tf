locals {
  traefik_tags = {
    type = "internal"
    app  = "traefik-ingress"
  }
  traefik_daemonset_tags = merge(local.traefik_tags, { component = "controller" })
}

resource "kubernetes_service_account" "traefik" {
  metadata {
    name      = "traefik-ingress"
    namespace = "kube-system"

    labels = local.traefik_tags
  }
}

resource "kubernetes_cluster_role" "traefik" {
  metadata {
    name   = "traefik-ingress"
    labels = local.traefik_tags
  }
  rule {
    api_groups = [""]
    resources  = ["services", "pods", "endpoints", "secrets"]
    verbs      = ["get", "watch", "list"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "watch", "list"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses/status"]
    verbs      = ["update"]
  }
}

resource "kubernetes_cluster_role_binding" "traefik" {
  metadata {
    name   = "traefik-ingress-access"
    labels = local.traefik_tags
  }
  role_ref {
    kind      = "ClusterRole"
    api_group = "rbac.authorization.k8s.io"
    name      = kubernetes_cluster_role.traefik.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.traefik.metadata[0].name
    namespace = kubernetes_service_account.traefik.metadata[0].namespace
  }
}

resource "kubernetes_config_map" "traefik_config" {
  metadata {
    name      = "traefik-ingress-config"
    namespace = "kube-system"
    labels    = local.traefik_tags
  }

  data = {
    "traefik.toml" = file(fileexists(var.traefik.config_file) ? var.traefik.config_file : "${path.module}/cfg/${var.traefik.config_file}")
  }
}

resource "kubernetes_persistent_volume_claim" "traefik_acme" {
  metadata {
    name      = "traefik-ingress-acme"
    namespace = "kube-system"
    labels    = local.traefik_tags
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class.traefik_acme.metadata[0].name
    resources {
      requests = {
        storage = "1Gi"
      }
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

resource "kubernetes_service" "traefik_loadbalancer" {
  metadata {
    name      = "traefik-ingress-lb"
    namespace = "kube-system"
    labels    = local.traefik_tags

    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-resource-group" = azurerm_resource_group.cluster.name
    }
  }

  spec {
    type                    = "LoadBalancer"
    external_traffic_policy = "Cluster"
    load_balancer_ip        = azurerm_public_ip.traefik_public_ip.ip_address
    selector                = local.traefik_daemonset_tags

    port {
      port        = 80
      name        = "http"
      target_port = "http"
    }

    port {
      port        = 443
      name        = "https"
      target_port = "https"
    }
  }
}

resource "kubernetes_daemonset" "traefik" {
  metadata {
    name      = "traefik-ingress-controller"
    namespace = "kube-system"
    labels    = local.traefik_tags
  }

  spec {
    selector {
      match_labels = local.traefik_daemonset_tags
    }

    template {
      metadata {
        labels = local.traefik_daemonset_tags
      }

      spec {
        service_account_name            = kubernetes_service_account.traefik.metadata[0].name
        automount_service_account_token = true

        termination_grace_period_seconds = 60

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

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.traefik_config.metadata[0].name
          }
        }
        volume {
          name = "acme"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.traefik_acme.metadata[0].name
          }
        }

        container {
          name  = "controller"
          image = "traefik:1.7"
          args = [
            "--configfile=/config/traefik.toml",
            "--metrics.datadog.address=$(DD_AGENT_HOST):8125",
            "--tracing.datadog.localagenthostport=$(DD_AGENT_HOST):8126"
          ]

          resources {
            requests {
              cpu    = "100m"
              memory = "50Mi"
            }
            limits {
              cpu    = var.traefik.resources.limits.cpu
              memory = var.traefik.resources.limits.memory
            }
          }

          readiness_probe {
            tcp_socket {
              port = "80"
            }
            failure_threshold     = 1
            initial_delay_seconds = 10
            period_seconds        = 10
            success_threshold     = 1
            timeout_seconds       = 2
          }
          liveness_probe {
            tcp_socket {
              port = "80"
            }
            failure_threshold     = 3
            initial_delay_seconds = 10
            period_seconds        = 10
            success_threshold     = 1
            timeout_seconds       = 2
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }
          volume_mount {
            name       = "acme"
            mount_path = "/acme"
          }

          port {
            name           = "http"
            protocol       = "TCP"
            container_port = 80
          }
          port {
            name           = "https"
            protocol       = "TCP"
            container_port = 443
          }
          port {
            name           = "httpn"
            protocol       = "TCP"
            container_port = 8880
          }
          port {
            name           = "dash"
            protocol       = "TCP"
            container_port = 8080
          }

          security_context {
            capabilities {
              drop = ["ALL"]
              add  = ["NET_BIND_SERVICE"]
            }
          }

          env {
            name = "AZURE_CLIENT_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.service_account.metadata[0].name
                key  = "client_id"
              }
            }
          }
          env {
            name = "AZURE_CLIENT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.service_account.metadata[0].name
                key  = "client_secret"
              }
            }
          }
          env {
            name = "AZURE_SUBSCRIPTION_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.service_account.metadata[0].name
                key  = "subscription_id"
              }
            }
          }
          env {
            name = "AZURE_TENANT_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.service_account.metadata[0].name
                key  = "tenant_id"
              }
            }
          }
          env {
            name = "AZURE_RESOURCE_GROUP"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.service_account.metadata[0].name
                key  = "resource_group"
              }
            }
          }
          env {
            name = "DD_AGENT_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }
        }
      }
    }
  }
}
