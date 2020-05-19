# We use it for Traefik ACME storage only and it shouldn't be used elsewhere.
resource "kubernetes_storage_class" "traefik_acme" {
  metadata {
    name = "traefik-acme"
  }
  storage_provisioner = "kubernetes.io/azure-file"
  mount_options       = ["dir_mode=0777", "file_mode=0600", "uid=0", "gid=0"]
  parameters = {
    skuName = "Standard_LRS"
  }
}

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
