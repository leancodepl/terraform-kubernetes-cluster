terraform-kubernetes-cluster
============================

An all-in-one solution for AKS cluster. Used internally at LeanCode.

## Managing helm releases

See [docs/managing-helm-releases.md](docs/managing-helm-releases.md).

## Known issues

### AzureRM `upgrade_override.effective_until` bug

AzureRM provider 4.x may fail to update AKS when `upgrade_override` is rendered without `effective_until`, because it sends an empty timestamp to Azure. See [hashicorp/terraform-provider-azurerm#28960](https://github.com/hashicorp/terraform-provider-azurerm/issues/28960).

For new clusters, set `force_upgrade_override = false` unless you explicitly need the `upgrade_override` block. For existing clusters where this module has already applied the block, keep `force_upgrade_override = true`; removing it can produce a state diff that cannot be applied cleanly.

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

