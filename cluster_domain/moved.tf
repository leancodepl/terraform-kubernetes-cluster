# Prevent destructive namespace operations
moved {
  from = kubernetes_namespace.external_dns
  to   = kubernetes_namespace_v1.external_dns
}

