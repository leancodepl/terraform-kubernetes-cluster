resource "kubernetes_storage_class" "traefik_acme" {
  metadata {
    name   = "traefik-acme"
    labels = local.ns_labels
  }
  storage_provisioner    = "kubernetes.io/azure-file"
  mount_options          = ["dir_mode=0777", "file_mode=0600", "uid=65532", "gid=65532"]
  allow_volume_expansion = false
  parameters = {
    skuName = "Standard_LRS"
  }
}
