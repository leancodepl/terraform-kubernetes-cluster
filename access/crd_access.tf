resource "kubernetes_cluster_role_v1" "crds_viewier" {
  metadata {
    name = "crds-viewer"
  }

  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "watch", "list"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "crds_viewier" {
  metadata {
    name = "crds-viewer"
  }

  role_ref {
    kind      = "ClusterRole"
    api_group = "rbac.authorization.k8s.io"
    name      = kubernetes_cluster_role_v1.crds_viewier.metadata[0].name
  }

  dynamic "subject" {
    for_each = var.viewers
    content {
      kind      = "Group"
      api_group = "rbac.authorization.k8s.io"
      name      = subject.key
    }
  }
}
