output "helm" {
  description = <<-EOT
    Helm chart configuration produced by this module, keyed by release name.
    Parameters are key/value pairs for use with Helm --set flags.
  EOT
  value = {
    (local.traefik_release.name) = {
      namespace             = kubernetes_namespace_v1.traefik.metadata[0].name
      repository            = local.traefik_release.repository
      chart                 = local.traefik_release.chart
      minimum_chart_version = local.traefik_release.minimum_chart_version
      parameters            = local.traefik_parameters
    }
  }
}

output "static_manifests" {
  description = "Static Kubernetes manifests produced by this module, keyed by wrapping helm release name."
  value = {
    "traefik-options" = {
      namespace           = kubernetes_namespace_v1.traefik.metadata[0].name
      depends_on_releases = [local.traefik_release.name]
      manifests = [
        file("${path.module}/charts/traefik-options/templates/sts-middleware.yaml"),
        file("${path.module}/charts/traefik-options/templates/tlsoptions.yaml"),
      ]
    }
  }
}
