locals {
  external_dns_tags = {
    type = "internal"
    app  = "external-dns"
  }
  external_dns_deployment_tags = merge(local.external_dns_tags, { component = "deployment" })
}

resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = "kube-system"

    labels = local.external_dns_tags
  }
}

resource "kubernetes_cluster_role" "external_dns" {
  metadata {
    name   = "external-dns"
    labels = local.external_dns_tags
  }
  rule {
    api_groups = [""]
    resources  = ["services", "pods"]
    verbs      = ["get", "watch", "list"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["list"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "watch", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "external_dns" {
  metadata {
    name   = "external-dns-access"
    labels = local.external_dns_tags
  }
  role_ref {
    kind      = "ClusterRole"
    api_group = "rbac.authorization.k8s.io"
    name      = kubernetes_cluster_role.external_dns.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.external_dns.metadata[0].name
    namespace = kubernetes_service_account.external_dns.metadata[0].namespace
  }
}

resource "kubernetes_deployment" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = "kube-system"
    labels    = local.external_dns_tags
  }

  spec {
    replicas = 1
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = local.external_dns_deployment_tags
    }

    template {
      metadata {
        labels = local.external_dns_deployment_tags
      }

      spec {
        service_account_name            = kubernetes_service_account.external_dns.metadata[0].name
        automount_service_account_token = true

        init_container {
          name  = "copy-the-config"
          image = "busybox"
          command = [
            "sh",
            "-c",
            "cp /etc/kubernetes-root/azure.json /etc/kubernetes/azure.json && chmod a+r /etc/kubernetes/azure.json",
          ]

          resources {
            requests {
              cpu    = "10m"
              memory = "10Mi"
            }
            limits {
              cpu    = "10m"
              memory = "10Mi"
            }
          }

          volume_mount {
            name       = "azure-config-file"
            mount_path = "/etc/kubernetes-root"
            read_only  = true
          }
          volume_mount {
            name       = "real-azure-config"
            mount_path = "/etc/kubernetes"
            read_only  = false
          }
        }

        container {
          name  = "externa-dns"
          image = "registry.opensource.zalan.do/teapot/external-dns:latest"

          args = [
            "--source=service",
            "--source=ingress",
            "--provider=azure",
            "--registry=txt",
            "--txt-owner-id=external-dns-${var.prefix}-k8s",
            "--azure-resource-group=$(AZURE_RESOURCE_GROUP)"
          ]

          resources {
            requests {
              cpu    = "10m"
              memory = "20Mi"
            }
            limits {
              cpu    = "100m"
              memory = "50Mi"
            }
          }

          volume_mount {
            name       = "real-azure-config"
            mount_path = "/etc/kubernetes"
            read_only  = true
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
        }

        volume {
          name = "azure-config-file"
          host_path {
            path = "/etc/kubernetes"
          }
        }
        volume {
          name = "real-azure-config"
          empty_dir {}
        }
      }
    }
  }

  # HACK: fix for upgrade from old K8s provider to the new one
  # Should be phased out before the PR
  lifecycle {
    ignore_changes = [spec[0].template[0].metadata[0].namespace]
  }
}
