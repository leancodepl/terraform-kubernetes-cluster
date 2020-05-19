resource "kubernetes_storage_class" "traefik_acme" {
  metadata {
    name = "traefik-acme"
  }
  storage_provisioner = "kubernetes.io/azure-file"
  mount_options       = ["dir_mode=0777", "file_mode=0777", "uid=1000", "gid=1000"]
  parameters = {
    sku_name = "Standard_LRS"
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
