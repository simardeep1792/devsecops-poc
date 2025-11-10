#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check prerequisites
print_step "Checking prerequisites..."
for tool in kind kubectl helm docker; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        print_error "Missing required tool: $tool"
        exit 1
    fi
done

echo "Setting up local DevSecOps PoC environment..."

echo "Creating kind cluster with registry..."
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: devsecops-poc
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "Waiting for NGINX Ingress deployment..."
kubectl wait --namespace ingress-nginx \
  --for=condition=available deployment/ingress-nginx-controller \
  --timeout=300s || {
    print_error "NGINX Ingress deployment failed to become ready"
    exit 1
}

echo "Waiting for NGINX Ingress pods..."
sleep 10
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s || {
    print_error "NGINX Ingress pods failed to become ready"
    exit 1
}

echo "Installing Prometheus with Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring || true

# Create ConfigMap for Grafana dashboard provisioning
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-provisioning
  namespace: monitoring
data:
  dashboards.yaml: |
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: true
      updateIntervalSeconds: 10
      allowUiUpdates: true
      options:
        path: /var/lib/grafana/dashboards
EOF

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.enabled=true \
  --set grafana.adminPassword=admin \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.searchNamespace=ALL \
  --wait

echo "Installing Argo CD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=180s || {
    print_error "Argo CD failed to become ready"
    exit 1
}

echo "Installing Argo Rollouts..."
kubectl create namespace argo-rollouts || true
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl wait --namespace argo-rollouts \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argo-rollouts \
  --timeout=90s || {
    print_error "Argo Rollouts failed to become ready"
    exit 1
}

# Deploy Grafana dashboard
echo "Deploying Grafana dashboard..."
if [ -f "k8s/base/configmap-grafana-dashboard.yaml" ]; then
    kubectl apply -f k8s/base/configmap-grafana-dashboard.yaml
fi

echo "Setup complete!"
echo ""
echo "Access points:"
echo "- Stable URL: http://poc-app.local (production users)"
echo "- QA URL: http://poc-app-qa.local (canary validation)"
echo "- Argo CD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Username: admin"
echo "  Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "- Grafana: kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Next steps:"
echo "1. Add to your /etc/hosts file:"
echo "   127.0.0.1 poc-app.local poc-app-qa.local"
echo "2. Build and push the initial image: ./scripts/build-and-push.sh v1.0.0"
echo "3. Deploy the application: kubectl apply -k k8s/base/"