#!/usr/bin/env bash
# =============================================================================
# mTLS Module Verification Script
# =============================================================================
# Runs comprehensive tests to verify the mTLS infrastructure is working.
#
# Usage:
#   ./verify.sh              # Run all tests
#   ./verify.sh --quick      # Skip workload tests (infrastructure only)
#   ./verify.sh --ci         # CI mode (non-interactive, fail fast)
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="mtls-test"
ISSUER_NAME="internal-ca-issuer"
BUNDLE_NAME="internal-ca-bundle"
CA_SECRET="internal-root-ca-secret"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Options
QUICK_MODE=false
CI_MODE=false

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)) || true; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)) || true; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

wait_for() {
    local description="$1"
    local command="$2"
    local timeout="${3:-60}"
    
    log_info "Waiting for $description (timeout: ${timeout}s)..."
    
    local elapsed=0
    while ! eval "$command" &>/dev/null; do
        if [[ $elapsed -ge $timeout ]]; then
            log_fail "$description (timeout after ${timeout}s)"
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log_pass "$description"
    return 0
}

# -----------------------------------------------------------------------------
# Infrastructure Tests
# -----------------------------------------------------------------------------

test_cert_manager() {
    log_info "=== Testing cert-manager ==="
    
    if kubectl get deployment cert-manager -n cert-manager &>/dev/null; then
        log_pass "cert-manager deployment exists"
    else
        log_fail "cert-manager deployment not found"
        return 1
    fi
    
    if kubectl get clusterissuer selfsigned-issuer &>/dev/null; then
        log_pass "selfsigned-issuer ClusterIssuer exists"
    else
        log_fail "selfsigned-issuer ClusterIssuer not found"
    fi
}

test_csi_driver() {
    log_info "=== Testing cert-manager CSI driver ==="
    
    if kubectl get csidrivers csi.cert-manager.io &>/dev/null; then
        log_pass "CSI driver registered"
    else
        log_fail "CSI driver not registered"
        return 1
    fi
    
    # Check DaemonSet is running
    local ready
    ready=$(kubectl get daemonset -n cert-manager -l app.kubernetes.io/name=cert-manager-csi-driver \
        -o jsonpath='{.items[0].status.numberReady}' 2>/dev/null || echo "0")
    
    if [[ "$ready" -gt 0 ]]; then
        log_pass "CSI driver DaemonSet running ($ready pods ready)"
    else
        log_fail "CSI driver DaemonSet not ready"
    fi
}

test_trust_manager() {
    log_info "=== Testing trust-manager ==="
    
    if kubectl get deployment trust-manager -n cert-manager &>/dev/null; then
        log_pass "trust-manager deployment exists"
    else
        log_fail "trust-manager deployment not found"
        return 1
    fi
    
    # Check Bundle CRD exists
    if kubectl get crd bundles.trust.cert-manager.io &>/dev/null; then
        log_pass "Bundle CRD registered"
    else
        log_fail "Bundle CRD not registered"
    fi
}

test_internal_ca() {
    log_info "=== Testing Internal CA ==="
    
    # Check ClusterIssuer
    if kubectl get clusterissuer "$ISSUER_NAME" &>/dev/null; then
        log_pass "Internal CA ClusterIssuer exists"
    else
        log_fail "Internal CA ClusterIssuer not found"
        return 1
    fi
    
    # Check ClusterIssuer is ready
    local ready
    ready=$(kubectl get clusterissuer "$ISSUER_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    
    if [[ "$ready" == "True" ]]; then
        log_pass "Internal CA ClusterIssuer is Ready"
    else
        log_fail "Internal CA ClusterIssuer is not Ready (status: $ready)"
    fi
    
    # Check CA secret
    if kubectl get secret "$CA_SECRET" -n cert-manager &>/dev/null; then
        log_pass "CA secret exists"
    else
        log_fail "CA secret not found"
    fi
}

test_trust_bundle() {
    log_info "=== Testing Trust Bundle ==="
    
    # Check Bundle resource
    if kubectl get bundle "$BUNDLE_NAME" &>/dev/null; then
        log_pass "Trust Bundle exists"
    else
        log_fail "Trust Bundle not found"
        return 1
    fi
    
    # Check namespace has the label
    local label
    label=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.mtls\.leancode\.pl/enabled}' 2>/dev/null)
    
    if [[ "$label" == "true" ]]; then
        log_pass "Test namespace has mTLS label"
    else
        log_fail "Test namespace missing mTLS label"
    fi
    
    # Check ConfigMap was synced to namespace
    if kubectl get configmap "$BUNDLE_NAME" -n "$NAMESPACE" &>/dev/null; then
        log_pass "Trust bundle ConfigMap synced to test namespace"
    else
        log_fail "Trust bundle ConfigMap not found in test namespace"
    fi
}

# -----------------------------------------------------------------------------
# Workload Tests
# -----------------------------------------------------------------------------

deploy_test_workloads() {
    log_info "=== Deploying Test Workloads ==="
    
    kubectl apply -f "$SCRIPT_DIR/test-workloads/server.yaml"
    kubectl apply -f "$SCRIPT_DIR/test-workloads/client.yaml"
    
    # Wait for server to be ready
    wait_for "server deployment ready" \
        "kubectl get deployment mtls-server -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q '1'" \
        120
    
    # Wait for client to be ready
    wait_for "client deployment ready" \
        "kubectl get deployment mtls-client -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q '1'" \
        120
}

test_csi_volume_mount() {
    log_info "=== Testing CSI Volume Mount ==="
    
    # Check server pod has certificates
    if kubectl exec -n "$NAMESPACE" deploy/mtls-server -- test -f /etc/nginx/ssl/tls.crt 2>/dev/null; then
        log_pass "Server certificate mounted via CSI"
    else
        log_fail "Server certificate not found"
        return 1
    fi
    
    # Check client pod has certificates
    if kubectl exec -n "$NAMESPACE" deploy/mtls-client -- test -f /etc/ssl/client/tls.crt 2>/dev/null; then
        log_pass "Client certificate mounted via CSI"
    else
        log_fail "Client certificate not found"
    fi
    
    # Check CA bundle is mounted
    if kubectl exec -n "$NAMESPACE" deploy/mtls-client -- test -f /etc/ssl/ca/ca-certificates.crt 2>/dev/null; then
        log_pass "CA bundle mounted from trust-manager"
    else
        log_fail "CA bundle not found"
    fi
}

test_mtls_connection() {
    log_info "=== Testing mTLS Connection ==="
    
    # Run the mTLS test script in the client pod
    local result
    result=$(kubectl exec -n "$NAMESPACE" deploy/mtls-client -- /scripts/test-mtls.sh 2>&1) || true
    
    echo "$result"
    
    if echo "$result" | grep -q "All mTLS tests passed"; then
        log_pass "mTLS connection test passed"
    else
        log_fail "mTLS connection test failed"
        return 1
    fi
}

cleanup_test_workloads() {
    log_info "Cleaning up test workloads..."
    kubectl delete -f "$SCRIPT_DIR/test-workloads/server.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/test-workloads/client.yaml" --ignore-not-found
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --ci)
                CI_MODE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--quick] [--ci]"
                echo ""
                echo "Options:"
                echo "  --quick   Skip workload tests (infrastructure only)"
                echo "  --ci      CI mode (non-interactive, fail fast)"
                echo "  -h, --help Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    echo ""
    echo "========================================"
    echo "  mTLS Module Verification"
    echo "========================================"
    echo ""
    
    # Infrastructure tests
    test_cert_manager
    test_csi_driver
    test_trust_manager
    test_internal_ca
    test_trust_bundle
    
    # Workload tests (unless --quick)
    if [[ "$QUICK_MODE" == "false" ]]; then
        echo ""
        log_info "Running workload tests..."
        
        deploy_test_workloads
        test_csi_volume_mount
        test_mtls_connection
        
        if [[ "$CI_MODE" == "true" ]]; then
            cleanup_test_workloads
        else
            echo ""
            log_info "Test workloads left running for manual inspection."
            echo "  View server logs: kubectl logs -n $NAMESPACE deploy/mtls-server"
            echo "  Exec into client: kubectl exec -n $NAMESPACE -it deploy/mtls-client -- sh"
            echo "  Cleanup: kubectl delete -f $SCRIPT_DIR/test-workloads/"
        fi
    else
        log_skip "Workload tests (--quick mode)"
    fi
    
    # Summary
    echo ""
    echo "========================================"
    echo "  Results: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
    echo "========================================"
    echo ""
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
    
    exit 0
}

main "$@"
