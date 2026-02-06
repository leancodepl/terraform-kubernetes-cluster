output "plugin" {
  description = "The output of this plugin to be passed to follow-up plugins."
  value = {
    namespace_name = kubernetes_namespace_v1.istio_system.metadata[0].name
  }
}
