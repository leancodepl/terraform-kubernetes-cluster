# Prevent destructive namespace operations
moved {
  from = kubernetes_namespace.traefik
  to   = kubernetes_namespace_v1.traefik
}

