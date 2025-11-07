.PHONY: help setup build deploy demo clean status dashboards test prerequisites check-cluster

# Default target
help:
	@echo "DevSecOps PoC - Available Commands"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make prerequisites  - Check system prerequisites"
	@echo "  make setup         - Create local cluster and install components"
	@echo "  make clean         - Destroy cluster and cleanup"
	@echo ""
	@echo "Application Commands:"
	@echo "  make build         - Build and push application image"
	@echo "  make deploy        - Deploy application to cluster"
	@echo "  make status        - Show application status"
	@echo ""
	@echo "Demo Commands:"
	@echo "  make demo          - Run full interactive demo"
	@echo "  make demo-quick    - Quick application test"
	@echo "  make demo-canary   - Canary deployment demo"
	@echo "  make demo-monitor  - Live monitoring"
	@echo ""
	@echo "Monitoring Commands:"
	@echo "  make dashboards    - Open monitoring dashboards"
	@echo "  make logs          - Show application logs"
	@echo "  make test          - Test application endpoints"
	@echo ""

prerequisites:
	@echo "Checking prerequisites..."
	@./scripts/check-prerequisites.sh

setup: prerequisites
	@echo "Setting up DevSecOps PoC environment..."
	@./scripts/setup-local.sh
	@echo "Setup complete. Add '127.0.0.1 poc-app.local' to /etc/hosts if not already present."

build:
	@echo "Building application..."
	@./scripts/build-and-push.sh v1.0.0

deploy: check-cluster
	@echo "Deploying application..."
	@kubectl apply -k k8s/base/
	@echo "Waiting for rollout..."
	@kubectl argo rollouts status poc-app -n poc-demo --timeout=300s || true

status: check-cluster
	@./scripts/show-apps.sh status

demo: check-cluster
	@./scripts/demo.sh

demo-quick: check-cluster
	@./scripts/show-apps.sh quick

demo-canary: check-cluster
	@./scripts/demo.sh canary

demo-monitor: check-cluster
	@./scripts/show-apps.sh monitor

dashboards: check-cluster
	@./scripts/demo.sh dashboards

logs: check-cluster
	@echo "Application logs:"
	@kubectl logs -n poc-demo -l app=poc-app --tail=50

test: check-cluster
	@echo "Testing application endpoints..."
	@curl -s http://poc-app.local/health || echo "Health check failed"
	@curl -s http://poc-app.local/version || echo "Version check failed"

clean:
	@echo "Cleaning up..."
	@kind delete cluster --name devsecops-poc || true
	@docker rm -f local-registry || true

check-cluster:
	@kubectl cluster-info --context kind-devsecops-poc >/dev/null 2>&1 || \
		(echo "Cluster not running. Run 'make setup' first." && exit 1)

# Advanced workflows
reset: clean setup build deploy
	@echo "Environment reset complete"

full-demo: setup build deploy demo
	@echo "Full demo complete"