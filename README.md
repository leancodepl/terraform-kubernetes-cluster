terraform-kubernetes-cluster
============================

An all-in-one solution for AKS cluster. Used internally at LeanCode.

## Migrating to kubernetes versioned resource types

Concerns version >= 25.0. Kubernetes provider 3.0 deprecates non-versioned resource types (e.g. `kubernetes_namespace` → `kubernetes_namespace_v1`). Terraform's `moved` block does **not** support changing resource types, so use state commands:

```bash
# Generic pattern
terraform state rm kubernetes_namespace.<name>
terraform import kubernetes_namespace_v1.<name> <namespace-name>

# Example for monitoring module
terraform state rm module.monitoring.kubernetes_namespace.main
terraform import module.monitoring.kubernetes_namespace_v1.main monitoring
```

### Affected namespaces

| Module             | Resource                               | Namespace      |
|--------------------|----------------------------------------|----------------|
| `monitoring`       | `kubernetes_namespace_v1.main`         | `monitoring`   |
| `traefik_ingress`  | `kubernetes_namespace_v1.traefik`      | `traefik`      |
| `cluster_domain`   | `kubernetes_namespace_v1.external_dns` | `external-dns` |
