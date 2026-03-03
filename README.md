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

Both `cluster_domain` and `traefik_ingress` support `manage_helm_release` (defaults to `true`) to allow managing Helm releases externally (e.g. via ArgoCD). Both modules expose outputs with the configuration needed to recreate the releases outside of Terraform.

### cluster_domain

If you want to keep managing External DNS from this module (`manage_helm_release = true`), no manual state migration is required. This release includes an internal Terraform `moved` block from `helm_release.external_dns` to `helm_release.external_dns[0]`.

If you want to manage the Helm release outside of this module:

1. Set `manage_helm_release = false` on `module.cluster_domain`.
2. Remove state for the old release to avoid destroy/apply conflicts (one of the addresses will exist, depending on whether state was already migrated):

```bash
terraform state rm module.cluster_domain.helm_release.external_dns
terraform state rm module.cluster_domain.helm_release.external_dns[0]
```

3. Recreate the release in your own stack using:
   - `module.cluster_domain.helm.<release>.values` as ready-to-use `values.yaml` content (YAML string).
   - `module.cluster_domain.helm.<release>.parameters` for key/value Helm parameters.

### traefik_ingress

`traefik_ingress` manages two resources: the `traefik` Helm release (versioned) and a set of static Traefik CRD instances (`Middleware`, `TLSOption`). Both are gated by `manage_helm_release`.

The static CRD instances cannot use `kubernetes_manifest` due to a Terraform provider limitation (schema must be known at plan time, which requires CRDs to already exist). When managed by this module they are wrapped in a local Helm chart (`traefik-options`) as a workaround. When managed externally they can be applied as plain YAML — see `output.static_manifests`.

If you want to keep managing both from this module (`manage_helm_release = true`), no manual state migration is required. This release includes internal Terraform `moved` blocks.

If you want to manage the releases outside of this module (e.g. ArgoCD):

1. Set `manage_helm_release = false` on `module.traefik_ingress`.
2. Remove state for the old releases to avoid destroy/apply conflicts (one of the addresses will exist, depending on whether state was already migrated):

```bash
terraform state rm module.traefik_ingress.helm_release.traefik
terraform state rm module.traefik_ingress.helm_release.traefik[0]
terraform state rm module.traefik_ingress.helm_release.traefik_options
terraform state rm module.traefik_ingress.helm_release.traefik_options[0]
```

3. Recreate the Helm release using `module.traefik_ingress.helm.<release>.parameters` for key/value `--set` flags.
4. Deploy the static CRD instances from `module.traefik_ingress.static_manifests.traefik-options.manifests` — each entry is a ready-to-use YAML string. In ArgoCD, use sync waves to ensure the `traefik` Application is healthy before applying these (they depend on CRDs installed by Traefik).
