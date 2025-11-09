#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

function print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

function print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function wait_for_user() {
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
    echo ""
}

function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

function check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_tools=""
    
    for tool in kubectl curl jq docker; do
        if ! command_exists "$tool"; then
            missing_tools="$missing_tools $tool"
        fi
    done
    
    if [ -n "$missing_tools" ]; then
        print_error "Missing required tools:$missing_tools"
        print_info "Please install missing tools and run again"
        exit 1
    fi
    
    # Check if poc-app.local is in /etc/hosts
    if ! grep -q "poc-app.local" /etc/hosts; then
        print_warning "poc-app.local not found in /etc/hosts"
        print_info "Run: echo '127.0.0.1 poc-app.local' | sudo tee -a /etc/hosts"
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info --context kind-devsecops-poc >/dev/null 2>&1; then
        print_error "Cannot connect to kind cluster 'devsecops-poc'"
        print_info "Run 'make setup' to create the cluster"
        exit 1
    fi
    
    # Check if required namespaces exist
    for ns in poc-demo monitoring; do
        if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
            print_warning "Namespace '$ns' not found"
            print_info "Run 'make setup' to complete installation"
            exit 1
        fi
    done
    
    print_info "All prerequisites met ✓"
}

function open_dashboard() {
    local url="$1"
    local name="$2"
    
    print_info "Opening $name dashboard: $url"
    
    case "$(uname)" in
        "Darwin")
            open "$url"
            ;;
        "Linux")
            if command_exists xdg-open; then
                xdg-open "$url"
            else
                print_info "Please open $url in your browser"
            fi
            ;;
        *)
            print_info "Please open $url in your browser"
            ;;
    esac
}

function show_status() {
    print_step "Current rollout status:"
    kubectl argo rollouts get rollout poc-app -n poc-demo
    echo ""
}

function test_endpoint() {
    print_step "Testing endpoints:"
    print_info "Stable endpoint:"
    curl -s http://poc-app.local/version | jq .
    echo ""
    print_info "Canary endpoint (x-testing: true header):"
    curl -s -H "x-testing: true" http://poc-app.local/version | jq .
    echo ""
}

function generate_traffic() {
    print_info "Starting background traffic generator..."
    while true; do
        curl -s http://poc-app.local/health > /dev/null 2>&1
        curl -s http://poc-app.local/work > /dev/null 2>&1
        sleep 0.1
    done &
    TRAFFIC_PID=$!
    print_info "Traffic generator running (PID: $TRAFFIC_PID)"
}

function stop_traffic() {
    if [ ! -z "$TRAFFIC_PID" ]; then
        kill $TRAFFIC_PID 2>/dev/null || true
        print_info "Traffic generator stopped"
    fi
}

function demo_mode() {
    case "$1" in
        "prerequisites"|"prereq"|"check")
            check_prerequisites
            ;;
        "initial"|"1")
            demo_initial_state
            ;;
        "canary"|"2") 
            demo_canary_deployment
            ;;
        "failure"|"3")
            demo_failure_rollback
            ;;
        "latency"|"4")
            demo_latency_rollback
            ;;
        "sbom"|"5")
            demo_sbom
            ;;
        "dashboards"|"ui")
            open_dashboards
            ;;
        "all"|"")
            run_full_demo
            ;;
        *)
            show_usage
            ;;
    esac
}

function show_usage() {
    print_header "DevSecOps PoC Demo Script"
    echo -e "${GREEN}Usage:${NC} $0 [mode]"
    echo ""
    echo -e "${CYAN}Available modes:${NC}"
    echo "  prerequisites  - Check system prerequisites"
    echo "  initial       - Demo 1: Show initial deployment state"
    echo "  canary        - Demo 2: Canary deployment"
    echo "  failure       - Demo 3: Failure rollback"
    echo "  latency       - Demo 4: Latency rollback" 
    echo "  sbom          - Demo 5: Show SBOM artifacts"
    echo "  dashboards    - Open monitoring dashboards"
    echo "  all           - Run complete demo (default)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0              # Run full demo"
    echo "  $0 initial      # Show current state only"
    echo "  $0 canary       # Run canary deployment demo"
    echo "  $0 dashboards   # Open Argo CD and Prometheus"
}

function demo_initial_state() {
    print_header "Demo 1: Initial State"
    show_status
    test_endpoint
    wait_for_user
}

function demo_canary_deployment() {
    print_header "Demo 2: Successful Canary Deployment (v1.1.0)"
    
    print_info "What will happen:"
    echo "  1. Deploy v1.1.0 as canary (starts at 0% traffic)"
    echo "  2. Progressively increase traffic: 0% → 20% → 50% → 80% → 100%"
    echo "  3. Each step waits 30s and checks success rate > 99%"
    echo "  4. Automatic promotion if all checks pass"
    wait_for_user
    
    print_step "Building and deploying v1.1.0..."
    ./scripts/build-and-push.sh v1.1.0
    
    print_step "Triggering canary deployment..."
    kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:v1.1.0 -n poc-demo
    
    print_info "Waiting 60s for metrics to stabilize before analysis..."
    sleep 60
    
    print_info "Starting traffic generation and watching rollout progress..."
    generate_traffic
    kubectl argo rollouts get rollout poc-app -n poc-demo --watch
    stop_traffic
    
    test_endpoint
    wait_for_user
}

function demo_failure_rollback() {
    print_header "Demo 3: Failed Canary - High Error Rate (v1.2.0)"
    print_step "Building and deploying v1.2.0 (30% error rate)..."
    ./scripts/build-and-push.sh v1.2.0
    kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:v1.2.0 -n poc-demo
    print_info "Watch the automatic rollback due to errors..."
    generate_traffic
    kubectl argo rollouts get rollout poc-app -n poc-demo --watch
    stop_traffic
    test_endpoint
    wait_for_user
}

function demo_latency_rollback() {
    print_header "Demo 4: Failed Canary - High Latency (v1.3.0)"
    print_step "Building and deploying v1.3.0 (2s latency)..."
    ./scripts/build-and-push.sh v1.3.0
    kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:v1.3.0 -n poc-demo
    print_info "Watch the automatic rollback due to latency..."
    generate_traffic
    kubectl argo rollouts get rollout poc-app -n poc-demo --watch
    stop_traffic
    test_endpoint
    wait_for_user
}

function demo_sbom() {
    print_header "Demo 5: View SBOM"
    print_step "Showing SBOM for v1.1.0:"
    if [ -f "sbom-v1.1.0.json" ]; then
        cat sbom-v1.1.0.json | jq '.packages[0:3]'
    else
        print_warning "SBOM file not found. Run build-and-push.sh first."
    fi
    echo ""
}

function open_dashboards() {
    print_header "Opening Monitoring Dashboards"
    
    print_step "Starting port forwards..."
    
    # Kill existing port forwards
    pkill -f "kubectl port-forward.*argocd" || true
    pkill -f "kubectl port-forward.*prometheus" || true
    pkill -f "kubectl port-forward.*rollouts" || true
    
    # Start Argo CD port forward
    kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &
    ARGOCD_PID=$!
    
    # Start Prometheus port forward  
    kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090 >/dev/null 2>&1 &
    PROMETHEUS_PID=$!
    
    # Start Grafana port forward
    kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 >/dev/null 2>&1 &
    GRAFANA_PID=$!
    
    # Start Argo Rollouts dashboard
    kubectl argo rollouts dashboard -n poc-demo >/dev/null 2>&1 &
    ROLLOUTS_PID=$!
    
    sleep 3
    
    print_info "Dashboards available at:"
    echo ""
    print_info "Argo CD: https://localhost:8080"
    print_info "  Username: admin"
    print_info "  Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
    echo ""
    print_info "Prometheus: http://localhost:9090"
    print_info "  Query examples:"
    print_info "  - rate(nginx_ingress_controller_requests[1m])"
    print_info "  - histogram_quantile(0.95, rate(nginx_ingress_controller_request_duration_seconds_bucket[1m]))"
    echo ""
    print_info "Argo Rollouts: http://localhost:3100"
    print_info "  View canary deployment progress"
    echo ""
    print_info "Grafana: http://localhost:3000"
    print_info "  Username: admin | Password: admin"
    print_info "  Dashboard: DevSecOps PoC - Rollout Dashboard"
    
    open_dashboard "https://localhost:8080" "Argo CD"
    open_dashboard "http://localhost:9090" "Prometheus"
    open_dashboard "http://localhost:3000" "Grafana"
    open_dashboard "http://localhost:3100" "Argo Rollouts"
    
    print_warning "Port forwards running in background"
    print_info "Press Ctrl+C to stop all port forwards"
    echo ""
    
    # Wait for all background processes
    trap "kill $ARGOCD_PID $PROMETHEUS_PID $GRAFANA_PID $ROLLOUTS_PID 2>/dev/null" EXIT
    wait $ARGOCD_PID $PROMETHEUS_PID $GRAFANA_PID $ROLLOUTS_PID
}

function run_full_demo() {
    print_header "DevSecOps PoC Demo Script"
    check_prerequisites
    demo_initial_state
    demo_canary_deployment
    demo_failure_rollback
    demo_latency_rollback
    demo_sbom
    
    print_header "Demo Complete"
    print_info "Key takeaways:"
    echo "  ✓ Canary deployments with header-based routing"
    echo "  ✓ Automatic promotion based on success metrics"
    echo "  ✓ Automatic rollback on failures"
    echo "  ✓ Security scanning with Trivy"
    echo "  ✓ SBOM generation for compliance"
    
    print_info "Want to explore dashboards? Run: $0 dashboards"
}

# Main execution
demo_mode "$1"