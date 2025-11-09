#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

function print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

function check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

function check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

function check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check cluster connection
print_header "Cluster Validation"
if kubectl cluster-info --context kind-devsecops-poc >/dev/null 2>&1; then
    check_pass "Connected to kind cluster 'devsecops-poc'"
else
    check_fail "Cannot connect to cluster"
    echo "Run 'make setup' to create the cluster"
    exit 1
fi

# Check required namespaces
print_header "Namespace Validation"
for ns in poc-demo monitoring ingress-nginx argocd argo-rollouts; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        check_pass "Namespace '$ns' exists"
    else
        check_fail "Namespace '$ns' missing"
    fi
done

# Check ingress controller
print_header "Ingress Controller Validation"
if kubectl get deployment -n ingress-nginx ingress-nginx-controller >/dev/null 2>&1; then
    check_pass "NGINX Ingress controller deployed"
    
    # Check if ready
    READY=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
    if [ "$READY" = "True" ]; then
        check_pass "NGINX Ingress controller ready"
    else
        check_fail "NGINX Ingress controller not ready"
    fi
else
    check_fail "NGINX Ingress controller not found"
fi

# Check monitoring stack
print_header "Monitoring Stack Validation"
if kubectl get deployment -n monitoring prometheus-kube-prometheus-operator >/dev/null 2>&1; then
    check_pass "Prometheus operator deployed"
else
    check_fail "Prometheus operator not found"
fi

if kubectl get deployment -n monitoring prometheus-grafana >/dev/null 2>&1; then
    check_pass "Grafana deployed"
    
    # Check dashboard ConfigMap
    if kubectl get cm -n monitoring devsecops-rollout-dashboard >/dev/null 2>&1; then
        check_pass "Grafana dashboard configured"
    else
        check_warn "Grafana dashboard ConfigMap missing"
    fi
else
    check_fail "Grafana not found"
fi

# Check application deployment
print_header "Application Deployment Validation"
if kubectl get rollout -n poc-demo poc-app >/dev/null 2>&1; then
    check_pass "Application rollout exists"
    
    # Check rollout status
    PHASE=$(kubectl get rollout -n poc-demo poc-app -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [ "$PHASE" = "Healthy" ]; then
        check_pass "Rollout is healthy"
    else
        check_warn "Rollout phase: $PHASE"
    fi
else
    check_fail "Application rollout not found"
fi

# Check services
print_header "Service Validation"
for svc in poc-app poc-app-stable poc-app-canary; do
    if kubectl get service -n poc-demo "$svc" >/dev/null 2>&1; then
        check_pass "Service '$svc' exists"
        
        # Check endpoints
        ENDPOINTS=$(kubectl get endpoints -n poc-demo "$svc" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
        if [ "$ENDPOINTS" -gt 0 ]; then
            check_pass "Service '$svc' has $ENDPOINTS endpoint(s)"
        else
            check_warn "Service '$svc' has no endpoints"
        fi
    else
        check_fail "Service '$svc' not found"
    fi
done

# Check ingress rules
print_header "Ingress Validation"
for ing in poc-app-stable poc-app-canary poc-app-canary-header; do
    if kubectl get ingress -n poc-demo "$ing" >/dev/null 2>&1; then
        check_pass "Ingress '$ing' exists"
        
        # Check if ingress has IP
        ADDRESS=$(kubectl get ingress -n poc-demo "$ing" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$ADDRESS" ]; then
            check_pass "Ingress '$ing' has address: $ADDRESS"
        else
            check_warn "Ingress '$ing' has no address assigned"
        fi
    else
        check_fail "Ingress '$ing' not found"
    fi
done

# Test application endpoints
print_header "Endpoint Testing"
if command -v curl >/dev/null 2>&1; then
    # Test stable endpoint
    if curl -s -f http://poc-app.local/health >/dev/null 2>&1; then
        check_pass "Stable endpoint responding"
        
        # Get version
        VERSION=$(curl -s http://poc-app.local/version | jq -r '.version' 2>/dev/null || echo "unknown")
        check_pass "Stable version: $VERSION"
    else
        check_fail "Stable endpoint not responding"
    fi
    
    # Test canary with header
    if curl -s -f -H "x-testing: true" http://poc-app.local/health >/dev/null 2>&1; then
        check_pass "Canary endpoint (header-based) responding"
        
        # Get version
        VERSION=$(curl -s -H "x-testing: true" http://poc-app.local/version | jq -r '.version' 2>/dev/null || echo "unknown")
        check_pass "Canary version: $VERSION"
    else
        check_warn "Canary endpoint (header-based) not responding"
    fi
else
    check_warn "curl not available, skipping endpoint tests"
fi

# Check Prometheus metrics
print_header "Metrics Validation"
if kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9091:9090 >/dev/null 2>&1 & then
    PF_PID=$!
    sleep 3
    
    # Query Prometheus
    if curl -s "http://localhost:9091/api/v1/query?query=up" >/dev/null 2>&1; then
        check_pass "Prometheus API accessible"
        
        # Check for ingress metrics
        METRIC_COUNT=$(curl -s "http://localhost:9091/api/v1/query?query=nginx_ingress_controller_requests" | jq '.data.result | length' 2>/dev/null || echo "0")
        if [ "$METRIC_COUNT" -gt 0 ]; then
            check_pass "NGINX Ingress metrics available ($METRIC_COUNT series)"
        else
            check_warn "No NGINX Ingress metrics found yet"
        fi
    else
        check_fail "Cannot query Prometheus API"
    fi
    
    kill $PF_PID 2>/dev/null
else
    check_warn "Cannot port-forward to Prometheus"
fi

# Summary
print_header "Validation Summary"
echo -e "Total checks: ${TOTAL_CHECKS}"
echo -e "Passed: ${GREEN}${PASSED_CHECKS}${NC}"
echo -e "Failed: ${RED}${FAILED_CHECKS}${NC}"

if [ "$FAILED_CHECKS" -eq 0 ]; then
    echo -e "\n${GREEN}All validation checks passed!${NC}"
    echo -e "The DevSecOps PoC is ready for demonstrations."
    exit 0
else
    echo -e "\n${RED}Some validation checks failed.${NC}"
    echo -e "Please review the failures above and run the appropriate setup commands."
    exit 1
fi