output "plugin" {
  description = "The output of this plugin to be passed to follow-up plugins."
  value = {
    namespace_name = kubernetes_namespace.main.metadata[0].name
  }
}
