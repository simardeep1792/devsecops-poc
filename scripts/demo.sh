#!/bin/bash
set -e

echo "=== DevSecOps PoC Demo Script ==="
echo ""

function wait_for_key() {
    echo ""
    read -p "Press Enter to continue..."
    echo ""
}

function show_status() {
    echo "Current rollout status:"
    kubectl argo rollouts get rollout poc-app -n poc-demo
    echo ""
}

function test_endpoint() {
    echo "Testing endpoint (stable):"
    curl -s http://poc-app.local/version | jq .
    echo ""
    echo "Testing endpoint (canary with x-testing header):"
    curl -s -H "x-testing: true" http://poc-app.local/version | jq .
    echo ""
}

function generate_traffic() {
    echo "Generating background traffic..."
    while true; do
        curl -s http://poc-app.local/health > /dev/null 2>&1
        curl -s http://poc-app.local/work > /dev/null 2>&1
        sleep 0.1
    done &
    TRAFFIC_PID=$!
    echo "Traffic generator PID: $TRAFFIC_PID"
}

function stop_traffic() {
    if [ ! -z "$TRAFFIC_PID" ]; then
        kill $TRAFFIC_PID 2>/dev/null || true
        echo "Stopped traffic generator"
    fi
}

echo "Demo 1: Initial State"
show_status
test_endpoint
wait_for_key

echo "Demo 2: Successful Canary Deployment (v1.1.0)"
echo "Building and deploying v1.1.0..."
./scripts/build-and-push.sh v1.1.0
kubectl argo rollouts set image poc-app poc-app=localhost:5000/poc-app:v1.1.0 -n poc-demo
echo ""
echo "Watch the rollout progress..."
generate_traffic
kubectl argo rollouts get rollout poc-app -n poc-demo --watch
stop_traffic
test_endpoint
wait_for_key

echo "Demo 3: Failed Canary - High Error Rate (v1.2.0)"
echo "Building and deploying v1.2.0 (30% error rate)..."
./scripts/build-and-push.sh v1.2.0
kubectl argo rollouts set image poc-app poc-app=localhost:5000/poc-app:v1.2.0 -n poc-demo
echo ""
echo "Watch the automatic rollback due to errors..."
generate_traffic
kubectl argo rollouts get rollout poc-app -n poc-demo --watch
stop_traffic
test_endpoint
wait_for_key

echo "Demo 4: Failed Canary - High Latency (v1.3.0)"
echo "Building and deploying v1.3.0 (2s latency)..."
./scripts/build-and-push.sh v1.3.0
kubectl argo rollouts set image poc-app poc-app=localhost:5000/poc-app:v1.3.0 -n poc-demo
echo ""
echo "Watch the automatic rollback due to latency..."
generate_traffic
kubectl argo rollouts get rollout poc-app -n poc-demo --watch
stop_traffic
test_endpoint
wait_for_key

echo "Demo 5: View SBOM"
echo "Showing SBOM for v1.1.0:"
cat sbom-v1.1.0.json | jq '.packages[0:3]'
echo ""

echo "=== Demo Complete ==="
echo ""
echo "Key takeaways:"
echo "- Canary deployments with header-based routing"
echo "- Automatic promotion based on success metrics"
echo "- Automatic rollback on failures"
echo "- Security scanning with Trivy"
echo "- Image signing with Cosign"
echo "- SBOM generation for compliance"