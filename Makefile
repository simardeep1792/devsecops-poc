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
	@echo "  make validate      - Run deployment validation checks"
	@echo ""
	@echo "QA Operations:"
	@echo "  make deploy-canary VERSION=v1.1.0 - Deploy canary at 0% traffic"
	@echo "  make promote-20    - QA approves: Start 20% production traffic"
	@echo "  make promote-50    - QA approves: Increase to 50% traffic"
	@echo "  make promote-80    - QA approves: Increase to 80% traffic"
	@echo "  make promote-100   - QA final approval: 100% traffic"
	@echo "  make rollback      - EMERGENCY: Full rollback to stable"
	@echo "  make rollout-status - Show detailed rollout status"
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
	@echo "Creating ArgoCD application..."
	@kubectl apply -f argocd/application.yaml || true
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

validate: check-cluster
	@./scripts/validate.sh

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

# QA Operations
promote: check-cluster
	@echo "Promoting to next rollout step..."
	@kubectl argo rollouts promote poc-app -n poc-demo
	@kubectl argo rollouts get rollout poc-app -n poc-demo

promote-20: check-cluster
	@echo "QA Approval: Promoting to 20% traffic..."
	@kubectl argo rollouts promote poc-app -n poc-demo
	@kubectl argo rollouts get rollout poc-app -n poc-demo

promote-50: check-cluster
	@echo "QA Approval: Promoting to 50% traffic..."
	@kubectl argo rollouts promote poc-app -n poc-demo
	@kubectl argo rollouts get rollout poc-app -n poc-demo

promote-80: check-cluster
	@echo "QA Approval: Promoting to 80% traffic..."
	@kubectl argo rollouts promote poc-app -n poc-demo
	@kubectl argo rollouts get rollout poc-app -n poc-demo

promote-100: check-cluster
	@echo "QA Final Approval: Promoting to 100% traffic..."
	@kubectl argo rollouts promote poc-app -n poc-demo
	@kubectl argo rollouts get rollout poc-app -n poc-demo

deploy-canary: check-cluster
	@echo "Deploying new canary version (0% traffic)..."
	@if [ -z "$(VERSION)" ]; then echo "Usage: make deploy-canary VERSION=v1.1.0"; exit 1; fi
	@kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:$(VERSION) -n poc-demo
	@echo "Canary deployed at 0% traffic. QA can test at http://poc-app-qa.local"
	@kubectl argo rollouts get rollout poc-app -n poc-demo

rollback: check-cluster
	@echo "EMERGENCY: Full rollback to stable version..."
	@kubectl argo rollouts abort poc-app -n poc-demo
	@kubectl argo rollouts undo poc-app -n poc-demo
	@echo "Rollback complete. All traffic back to stable."
	@kubectl argo rollouts status poc-app -n poc-demo

pause-rollout: check-cluster
	@echo "Pausing rollout at current weight..."
	@kubectl argo rollouts pause poc-app -n poc-demo
	@echo "Rollout paused. Use 'make promote' to continue or 'make rollback' to abort."

rollout-status: check-cluster
	@echo "Current rollout status:"
	@kubectl argo rollouts get rollout poc-app -n poc-demo
	@echo ""
	@echo "Analysis runs:"
	@kubectl get analysisrun -n poc-demo -l rollout=poc-app --sort-by='.metadata.creationTimestamp' | tail -5