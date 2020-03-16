locals {
  custom_apps_tags = merge(local.tags, {
    app = "custom"
  })
}

resource "kubernetes_service_account" "custom_deployments" {
  metadata {
    name      = "deployments"
    namespace = "default"

    labels = local.custom_apps_tags
  }
}

resource "kubernetes_role_binding" "custom_deployments_roles" {
  metadata {
    name      = "deployments-role-binding"
    namespace = kubernetes_service_account.custom_deployments.metadata[0].namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }

  subject {
    kind      = "ServiceAccount"
    namespace = kubernetes_service_account.custom_deployments.metadata[0].namespace
    name      = kubernetes_service_account.custom_deployments.metadata[0].name
  }
}
