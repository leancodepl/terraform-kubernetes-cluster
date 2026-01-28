# mTLS Module Tests

Integration tests for the `mtls` Terraform module using a local k3d cluster. Tests both direct pod-to-pod mTLS and Traefik → backend mTLS proxy flow.

## Prerequisites

- Docker running
- [k3d](https://k3d.io) installed
- kubectl installed
- helm installed
- terraform installed

## Usage

### One-Command Setup

```bash
./setup.sh                 # Interactive mode
./setup.sh --ci            # CI mode (non-interactive, auto-recreate)
./setup.sh --skip-cluster  # Skip cluster creation (reuse existing)
```

This will:
1. Create a k3d cluster (`mtls-test`)
2. Install cert-manager
3. Install Traefik (with cross-namespace references enabled)
4. Apply the mTLS Terraform module (two-stage apply for CRD handling)
5. Create test namespaces with mTLS enabled (mtls-test, traefik)
6. Deploy Traefik mTLS resources (client cert, CA bundle, ServersTransport)

**Note:** The Terraform apply runs in two stages:
1. First, helm releases are applied to install CRDs (trust-manager Bundle CRD)
2. Then, all remaining resources are applied

### Run Verification

```bash
# Full verification (infrastructure + workloads)
./verify.sh

# Quick verification (infrastructure only)
./verify.sh --quick

# CI mode (non-interactive, cleanup after)
./verify.sh --ci
```

### Manual Testing

After running `./setup.sh`, you can manually test instead of using `verify.sh`:

```bash
# Deploy test workloads (required before running any tests)
kubectl apply -f test-workloads/

# Wait for pods to be ready
kubectl wait --for=condition=Available deployment/mtls-server -n mtls-test --timeout=120s
kubectl wait --for=condition=Available deployment/mtls-client -n mtls-test --timeout=120s

# Run mTLS test (includes direct mTLS + Traefik proxy test)
kubectl exec -n mtls-test deploy/mtls-client -- /scripts/test-mtls.sh

# Show certificate info
kubectl exec -n mtls-test deploy/mtls-client -- /scripts/show-certs.sh

# Exec into client for manual testing
kubectl exec -n mtls-test -it deploy/mtls-client -- sh

# Clean up workloads when done
kubectl delete -f test-workloads/
```

**Note:** If you ran `verify.sh --ci`, workloads were cleaned up automatically. You'll need to redeploy them with `kubectl apply -f test-workloads/` for manual testing.

### Cleanup

```bash
./teardown.sh
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Test Flow                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Direct mTLS (pod-to-pod):                                   │
│     mtls-client ──[mTLS]──► mtls-server                         │
│                                                                 │
│  2. Traefik Proxy mTLS:                                         │
│     mtls-client ──[HTTP]──► Traefik ──[mTLS]──► mtls-server     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

The tests validate:
- **Direct mTLS**: Client presents its cert, server validates against CA
- **Traefik mTLS**: Traefik presents its client cert to backend, backend validates against CA

## Test Cases

| Test | Description |
|------|-------------|
| cert-manager exists | Prerequisite check |
| CSI driver registered | `csi.cert-manager.io` CSIDriver exists |
| trust-manager deployed | Deployment and Bundle CRD exist |
| Internal CA ready | ClusterIssuer is Ready |
| Trust bundle synced | ConfigMap appears in labeled namespace |
| Traefik deployed | Traefik deployment exists with mTLS label |
| CSI volume mount | Certificates appear in pod volumes |
| mTLS connection | Client connects to server with mutual TLS |
| No-cert rejection | Server rejects connections without client cert |
| Traefik mTLS proxy | Traefik → backend mTLS connection works |
| ServersTransport exists | Traefik mTLS ServersTransport configured |
| Traefik client cert | Traefik client certificate exists |
| CA bundle in traefik ns | CA bundle copied to traefik namespace |

## CI Integration

The GitHub Actions workflow (`.github/workflows/test-mtls.yml`) uses the same scripts (`setup.sh`, `verify.sh`, `teardown.sh`) to ensure consistent behavior between local and CI testing.

Triggers:
- Push to `main` (changes to `mtls/**`, `traefik_ingress/**`, or `tests/mtls/**`)
- Pull requests (changes to `mtls/**`, `traefik_ingress/**`, or `tests/mtls/**`)
- Manual dispatch (with optional debug mode)

## Troubleshooting

### CSI driver pods not ready

```bash
kubectl get pods -n cert-manager -l app.kubernetes.io/name=cert-manager-csi-driver
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager-csi-driver
```

### Certificates not mounting

```bash
kubectl describe pod -n mtls-test -l app=mtls-server
kubectl logs -n cert-manager deploy/cert-manager
```

### Trust bundle not syncing

```bash
kubectl get bundle internal-ca-bundle -o yaml
kubectl logs -n cert-manager deploy/trust-manager
```

### Traefik mTLS not working

```bash
# Check ServersTransport
kubectl get serverstransport -n traefik -o yaml

# Check Traefik logs for TLS errors
kubectl logs -n traefik deploy/traefik --tail=50

# Check Traefik client certificate
kubectl get secret traefik-client-cert -n traefik

# Check CA bundle in traefik namespace
kubectl get secret internal-ca-bundle -n traefik
```

### Reset everything

```bash
./teardown.sh
./setup.sh
```
