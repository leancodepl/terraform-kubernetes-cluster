#!/usr/bin/env bash
# =============================================================================
# mTLS Test Environment Teardown
# =============================================================================
# Cleans up the k3d cluster and all test resources.
#
# Usage:
#   ./teardown.sh
#   ./teardown.sh --keep-terraform  # Keep Terraform state files
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="mtls-test"

# Colors for output
# RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

main() {
    local keep_terraform=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-terraform)
                keep_terraform=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--keep-terraform]"
                echo ""
                echo "Options:"
                echo "  --keep-terraform  Keep Terraform state files"
                echo "  -h, --help        Show this help message"
                exit 0
                ;;
            *)
                log_warn "Unknown option: $1"
                shift
                ;;
        esac
    done

    # Delete k3d cluster
    if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        log_info "Deleting k3d cluster '$CLUSTER_NAME'..."
        k3d cluster delete "$CLUSTER_NAME"
    else
        log_warn "Cluster '$CLUSTER_NAME' not found."
    fi

    # Clean up Terraform state
    if [[ "$keep_terraform" == "false" ]]; then
        log_info "Cleaning up Terraform state..."
        cd "$SCRIPT_DIR"
        rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
    else
        log_info "Keeping Terraform state files."
    fi

    log_info "Teardown complete."
}

main "$@"
