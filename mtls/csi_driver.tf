# =============================================================================
# cert-manager CSI Driver
# =============================================================================
# The CSI driver allows Pods to request certificates via volume mounts.
# Certificates are stored only in memory (tmpfs), never written to etcd,
# and are automatically renewed before expiry.
#
# Usage in Pod spec:
#   volumes:
#     - name: tls
#       csi:
#         driver: csi.cert-manager.io
#         volumeAttributes:
#           csi.cert-manager.io/issuer-name: internal-ca-issuer
#           csi.cert-manager.io/issuer-kind: ClusterIssuer
#           csi.cert-manager.io/dns-names: ${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local
#           # For authorization between services
#           csi.cert-manager.io/common-name: "${SERVICE_ACCOUNT_NAME}.${POD_NAMESPACE}"
# =============================================================================

resource "helm_release" "cert_manager_csi_driver" {
  name       = "cert-manager-csi-driver"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager-csi-driver"
  version    = var.helm_versions.csi_driver
  namespace  = local.cert_manager_ns

  set = [
    # CSI driver log level
    {
      name  = "app.logLevel"
      value = "1"
    },
    # Use memory-backed volumes for security
    {
      name  = "app.driver.csiDataDir"
      value = "/tmp/cert-manager-csi-driver"
    },
    # Liveness probe settings
    {
      name  = "livenessProbe.port"
      value = "9809"
    }
  ]
}
