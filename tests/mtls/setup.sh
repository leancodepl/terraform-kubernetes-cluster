#!/usr/bin/env bash
# =============================================================================
# mTLS Test Environment Setup
# =============================================================================
# Creates a k3d cluster and installs all prerequisites for testing the mTLS module.
#
# Usage:
#   ./setup.sh           # Full setup
#   ./setup.sh --skip-cluster  # Skip cluster creation (if already exists)
#
# Prerequisites:
#   - Docker running
#   - k3d installed (https://k3d.io)
#   - kubectl installed
#   - helm installed
#   - terraform installed
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="mtls-test"
CERT_MANAGER_VERSION="v1.19.2"
CI_MODE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# Check Prerequisites
# -----------------------------------------------------------------------------

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    command -v docker &>/dev/null || missing+=("docker")
    command -v k3d &>/dev/null || missing+=("k3d")
    command -v kubectl &>/dev/null || missing+=("kubectl")
    command -v helm &>/dev/null || missing+=("helm")
    command -v terraform &>/dev/null || missing+=("terraform")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    if ! docker info &>/dev/null; then
        log_error "Docker is not running. Please start Docker."
        exit 1
    fi
    
    log_info "All prerequisites met."
}

# -----------------------------------------------------------------------------
# Create k3d Cluster
# -----------------------------------------------------------------------------

create_cluster() {
    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        log_warn "Cluster '$CLUSTER_NAME' already exists."
        if [[ "$CI_MODE" == "true" ]]; then
            log_info "CI mode: Deleting existing cluster..."
            k3d cluster delete "$CLUSTER_NAME"
        else
            read -p "Delete and recreate? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Deleting existing cluster..."
                k3d cluster delete "$CLUSTER_NAME"
            else
                log_info "Using existing cluster."
                kubectl config use-context "k3d-$CLUSTER_NAME"
                return
            fi
        fi
    fi
    
    log_info "Creating k3d cluster '$CLUSTER_NAME'..."
    k3d cluster create --config "$SCRIPT_DIR/k3d-cluster.yaml"
    
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=120s
}

# -----------------------------------------------------------------------------
# Install cert-manager (prerequisite for mTLS module)
# -----------------------------------------------------------------------------

install_cert_manager() {
    log_info "Installing cert-manager ${CERT_MANAGER_VERSION}..."
    
    # Add jetstack repo
    helm repo add jetstack https://charts.jetstack.io --force-update
    helm repo update jetstack
    
    # Install cert-manager with CRDs
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version "$CERT_MANAGER_VERSION" \
        --set crds.enabled=true \
        --wait \
        --timeout 5m
    
    log_info "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available deployment/cert-manager \
        --namespace cert-manager --timeout=120s
    kubectl wait --for=condition=Available deployment/cert-manager-webhook \
        --namespace cert-manager --timeout=120s
    kubectl wait --for=condition=Available deployment/cert-manager-cainjector \
        --namespace cert-manager --timeout=120s
    
    # Wait a bit for webhook to be fully ready
    sleep 5
    
    log_info "cert-manager installed successfully."
}

# -----------------------------------------------------------------------------
# Install Traefik (for testing Traefik -> backend mTLS)
# -----------------------------------------------------------------------------

install_traefik() {
    log_info "Installing Traefik..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -
    
    # Add Traefik helm repo
    helm repo add traefik https://helm.traefik.io/traefik --force-update
    helm repo update traefik
    
    # Install Traefik
    # Enable allowCrossNamespace to allow IngressRoutes in other namespaces
    # to reference ServersTransport in the traefik namespace
    helm upgrade --install traefik traefik/traefik \
        --namespace traefik \
        --set ingressRoute.dashboard.enabled=false \
        --set service.type=ClusterIP \
        --set ports.web.port=80 \
        --set ports.web.exposedPort=80 \
        --set ports.websecure.port=443 \
        --set ports.websecure.exposedPort=443 \
        --set providers.kubernetesCRD.allowCrossNamespace=true \
        --wait \
        --timeout 5m
    
    log_info "Waiting for Traefik to be ready..."
    kubectl wait --for=condition=Available deployment/traefik \
        --namespace traefik --timeout=120s
    
    log_info "Traefik installed successfully."
}

# -----------------------------------------------------------------------------
# Apply Terraform (mTLS module)
# -----------------------------------------------------------------------------

apply_terraform() {
    log_info "Initializing Terraform..."
    cd "$SCRIPT_DIR"
    
    terraform init -upgrade
    
    # Two-stage apply is required because:
    # 1. First we need to install the helm releases (CSI driver + trust-manager)
    #    which create the CRDs (Bundle, etc.)
    # 2. Then we can create kubernetes_manifest resources that use those CRDs
    #
    # The kubernetes_manifest provider validates against the API server during
    # planning, so CRDs must exist before we can plan resources that use them.
    
    log_info "Stage 1: Installing helm releases (CSI driver + trust-manager)..."
    terraform apply -auto-approve \
        -target=module.mtls.helm_release.cert_manager_csi_driver \
        -target=module.mtls.helm_release.trust_manager
    
    # Wait for CRDs to be fully registered
    log_info "Waiting for CRDs to be ready..."
    kubectl wait --for=condition=Established crd/bundles.trust.cert-manager.io --timeout=60s
    
    log_info "Stage 2: Applying remaining resources..."
    terraform apply -auto-approve
    
    log_info "Terraform apply completed."
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    local skip_cluster=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-cluster)
                skip_cluster=true
                shift
                ;;
            --ci)
                CI_MODE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--skip-cluster] [--ci]"
                echo ""
                echo "Options:"
                echo "  --skip-cluster  Skip k3d cluster creation"
                echo "  --ci            CI mode (non-interactive, auto-recreate cluster)"
                echo "  -h, --help      Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    check_prerequisites
    
    if [[ "$skip_cluster" == "false" ]]; then
        create_cluster
    fi
    
    install_cert_manager
    install_traefik
    apply_terraform
    
    echo ""
    log_info "==========================================="
    log_info "Setup complete!"
    log_info "==========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Run verification:  ./verify.sh"
    echo "     (This deploys test workloads, runs mTLS tests, and cleans up)"
    echo "  2. Cleanup when done: ./teardown.sh"
    echo ""
}

main "$@"
