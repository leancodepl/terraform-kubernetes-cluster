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

## Managing helm releases

`cluster_domain` now exposes Helm configuration in `output.helm` and adds `manage_helm_release` (defaults to `true`).

If you want to keep managing External DNS from this module (`manage_helm_release = true`), no manual state migration is required. This release includes an internal Terraform `moved` block from `helm_release.external_dns` to `helm_release.external_dns[0]`.

If you want to manage Helm release outside of this module:

1. Set `manage_helm_release = false` on `module.cluster_domain`.
2. Remove state for the old release to avoid destroy/apply conflicts (one of the addresses will exist, depending on whether state was already migrated):

```bash
terraform state rm module.cluster_domain.helm_release.external_dns
terraform state rm module.cluster_domain.helm_release.external_dns[0]
```

3. Recreate the release in your own stack using:
   - `module.cluster_domain.helm.values` for nested chart values.
   - `module.cluster_domain.helm.parameters` for key/value Helm parameters.
