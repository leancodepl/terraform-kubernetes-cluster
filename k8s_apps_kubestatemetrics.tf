locals {
  kubestatemetrics_tags = {
    type = "internal"
    app  = "kube-state-metrics"
  }
  kubestatemetrics_deployment_tags = merge(local.traefik_tags, { component = "main" })
}

resource "kubernetes_service_account" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = "kube-system"

    labels = local.kubestatemetrics_tags
  }
}

resource "kubernetes_cluster_role" "kube_state_metrics" {
  metadata {
    name   = "kube-state-metrics"
    labels = local.kubestatemetrics_tags
  }
  rule {
    api_groups = [""]
    resources = [
      "configmaps",
      "secrets",
      "nodes",
      "pods",
      "services",
      "resourcequotas",
      "replicationcontrollers",
      "limitranges",
      "persistentvolumeclaims",
      "persistentvolumes",
      "namespaces",
      "endpoints"
    ]
    verbs = ["watch", "list"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["daemonsets", "deployments", "replicasets", "statefulsets"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["authentication.k8s.io"]
    resources  = ["tokenreviews"]
    verbs      = ["create"]
  }
  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = ["subjectaccessreviews"]
    verbs      = ["create"]
  }
  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["certificatesigningrequests"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses", "volumeattachments"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["admissionregistration.k8s.io"]
    resources  = ["mutatingwebhookconfigurations", "validatingwebhookconfigurations"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["networkpolicies"]
    verbs      = ["watch", "list"]
  }
  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["watch", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "kube_state_metrics_access" {
  metadata {
    name   = "kube-state-metrics"
    labels = local.kubestatemetrics_tags
  }
  role_ref {
    kind      = "ClusterRole"
    api_group = "rbac.authorization.k8s.io"
    name      = kubernetes_cluster_role.kube_state_metrics.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kube_state_metrics.metadata[0].name
    namespace = kubernetes_service_account.kube_state_metrics.metadata[0].namespace
  }
}

resource "kubernetes_deployment" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = "kube-system"

    labels = local.kubestatemetrics_tags
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.kubestatemetrics_deployment_tags
    }

    template {
      metadata {
        labels = local.kubestatemetrics_deployment_tags
      }

      spec {
        automount_service_account_token = true
        service_account_name            = kubernetes_service_account.kube_state_metrics.metadata[0].name
        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        container {
          name = "kube-state-metrics"
          # We use `latest` 'cause most of our clusters will be up-to-date and kube-state-metrics
          # supports latest K8s only on master
          image = "quay.io/coreos/kube-state-metrics:latest"
          security_context {
            run_as_user = 65534
          }

          resources {
            requests {
              cpu    = "100m"
              memory = "200Mi"
            }
            limits {
              cpu    = "200m"
              memory = "300Mi"
            }
          }

          port {
            container_port = 8080
            name           = "http-metrics"
          }
          port {
            container_port = "8081"
            name           = "telemetry"
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8081
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
          }
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

resource "kubernetes_service" "kube_state_metrics_incluster_access" {
  metadata {
    name      = "kube-state-metrics-svc"
    namespace = "kube-system"
    labels    = local.kubestatemetrics_tags
  }

  spec {
    type     = "ClusterIP"
    selector = local.kubestatemetrics_deployment_tags

    port {
      name        = "http-metrics"
      port        = 8080
      target_port = "http-metrics"
    }

    port {
      name        = "telemetry"
      port        = 8081
      target_port = "telemetry"
    }
  }
}
