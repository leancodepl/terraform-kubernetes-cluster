# We use it for Traefik ACME storage only and it shouldn't be used elsewhere.
resource "kubernetes_cluster_role_binding" "azure_cloud_provider" {
  metadata {
    name = "azure-cloud-provider"
  }

  role_ref {
    kind      = "ClusterRole"
    api_group = "rbac.authorization.k8s.io"
    name      = "system:azure-cloud-provider"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "persistent-volume-binder"
    namespace = "kube-system"
  }
}
