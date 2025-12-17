# Prevent destructive namespace operations
moved {
  from = kubernetes_namespace.main
  to   = kubernetes_namespace_v1.main
}

