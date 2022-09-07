output "traefik_args" {
  description = "Args to pass to Traefik ingress plugin."
  value = [
    "--metrics.datadog=true",
    "--metrics.datadog.address=$(AGENT_HOST_IP):8125",
    "--tracing.jaeger.propagation=b3",
    "--tracing.jaeger.collector.endpoint=http://${kubernetes_service_v1.opentelemetry_service.metadata[0].name}.${var.monitoring_plugin.namespace_name}.svc.cluster.local:14268/api/traces?format=jaeger.thrift"
  ]
}

output "traefik_config" {
  description = "Config to pass to Traefik ingress plugin."
  value = {
    "env[0].name"                         = "AGENT_HOST_IP",
    "env[0].valueFrom.fieldRef.fieldPath" = "status.hostIP",
  }
}
