# DevSecOps PoC - Usage Guide

## Quick Reference

### Essential Commands

```bash
# Setup and validation
make prerequisites      # Check system requirements
make setup             # Create cluster with all components
make build             # Build and push application image
make deploy            # Deploy application to cluster

# Demonstrations  
make demo              # Full interactive demonstration
make demo-quick        # Quick endpoint testing
make demo-canary       # Canary deployment demo
make demo-monitor      # Live application monitoring

# Operations
make status            # Show application status
make logs              # View application logs
make test              # Test application endpoints
make dashboards        # Open monitoring dashboards
make clean             # Destroy environment
```

## Complete Workflows

### First-Time Setup

```bash
# 1. Validate environment
make prerequisites

# 2. Create infrastructure  
make setup

# 3. Deploy application
make build deploy

# 4. Run demonstrations
make demo
```

### Development Workflow

```bash
# Make code changes
vim app/main.go

# Build new version
./scripts/build-and-push.sh v1.1.0

# Deploy with progressive delivery
kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:v1.1.0 -n poc-demo

# Monitor deployment
make demo-monitor
```

### Troubleshooting Workflow

```bash
# Check system status
make status

# View detailed logs
make logs

# Reset environment if needed
make clean setup build deploy
```

## Use Case Scenarios

### Scenario: Executive Demo

**Objective**: Show business value of progressive deployment

```bash
# Setup (5 minutes)
make prerequisites
make setup build deploy

# Demo (15 minutes)  
make demo              # Shows full progressive delivery workflow
make dashboards        # Open visual monitoring
```

**Key Points**:
- Zero-downtime deployments
- Automatic rollback on failures
- Metrics-driven decisions
- Security scanning integration

### Scenario: Technical Deep Dive

**Objective**: Demonstrate technical implementation

```bash
# Show architecture
make status                           # Current state
./scripts/show-apps.sh demo          # Side-by-side comparison
kubectl argo rollouts get rollout poc-app -n poc-demo  # Detailed status
```

**Key Points**:
- Header-based traffic splitting
- Prometheus metrics integration  
- Automated analysis templates
- Kubernetes-native implementation

### Scenario: Security Validation

**Objective**: Show security controls

```bash
# Build with security scanning
make build                           # Shows Trivy output

# View security artifacts
cat sbom-v1.0.0.json | jq '.packages[0:5]'  # SBOM contents

# Check deployment policies
kubectl describe rollout poc-app -n poc-demo
```

**Key Points**:
- Vulnerability scanning in build
- Software Bill of Materials
- Policy-driven deployments
- Compliance automation

### Scenario: Failure Response

**Objective**: Demonstrate automated rollback

```bash
# Deploy version with high error rate
./scripts/build-and-push.sh v1.2.0
kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:v1.2.0 -n poc-demo

# Watch automatic rollback
kubectl argo rollouts get rollout poc-app -n poc-demo --watch
```

**Key Points**:
- Automatic failure detection
- Metrics-based rollback triggers
- Zero human intervention required
- Immediate reversion to stable state

## Monitoring and Observability

### Real-Time Monitoring

```bash
# Application monitoring
./scripts/show-apps.sh monitor       # Live endpoint testing

# Infrastructure monitoring  
make dashboards                      # Prometheus and Argo CD

# Deployment monitoring
kubectl argo rollouts get rollout poc-app -n poc-demo --watch
```

### Application Testing

```bash
# Basic connectivity
curl http://poc-app.local/health
curl http://poc-app.local/version

# Canary testing
curl -H "x-testing: true" http://poc-app.local/version

# Load simulation
curl "http://poc-app.local/work?delay=100"
```

## Advanced Operations

### Custom Version Deployment

```bash
# Build specific version
./scripts/build-and-push.sh v2.0.0

# Deploy with custom parameters
kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:v2.0.0 -n poc-demo

# Monitor rollout progress
kubectl argo rollouts status poc-app -n poc-demo
```

### Environment Management

```bash
# Check cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# Resource utilization
kubectl top nodes
kubectl top pods -n poc-demo

# Storage and networking
kubectl get pv,pvc
kubectl get ingress -n poc-demo
```

### Debugging Failed Deployments

```bash
# Check rollout status
kubectl argo rollouts get rollout poc-app -n poc-demo

# View analysis results
kubectl get analysisrun -n poc-demo
kubectl describe analysisrun -n poc-demo $(kubectl get analysisrun -n poc-demo -o name | head -1)

# Check metrics
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
# Query: rate(nginx_ingress_controller_requests[1m])
```

## Integration Points

### CI/CD Integration

The PoC provides patterns for:

```bash
# Build stage
make build                           # Docker build with security scanning

# Deploy stage  
kubectl apply -k k8s/base/          # GitOps-ready manifests

# Validate stage
make test                           # Endpoint validation
```

### GitOps Integration

```bash
# View Argo CD configuration
cat argocd/application.yaml

# Check synchronization
kubectl get application -n argocd

# Manual sync if needed
kubectl patch application poc-app -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"apply":{"force":true}}}}}' --type=merge
```

## Performance Considerations

### Resource Requirements

- **CPU**: 4 cores minimum for kind cluster
- **Memory**: 8GB minimum for all components  
- **Storage**: 10GB for images and logs
- **Network**: Ports 80, 443, 8080, 9090

### Scaling Considerations

```bash
# Horizontal scaling
kubectl scale rollout poc-app --replicas=5 -n poc-demo

# Resource adjustment
kubectl patch rollout poc-app -n poc-demo -p '{"spec":{"template":{"spec":{"containers":[{"name":"poc-app","resources":{"requests":{"cpu":"100m","memory":"128Mi"}}}]}}}}'
```

## Cleanup and Maintenance

### Cleanup Procedures

```bash
# Application cleanup
kubectl delete -k k8s/base/

# Complete environment cleanup
make clean

# Docker cleanup
docker system prune -f
```

### Log Management

```bash
# View recent logs
make logs

# Stream logs
kubectl logs -f -n poc-demo -l app=poc-app

# Export logs
kubectl logs -n poc-demo -l app=poc-app > app-logs.txt
```

This guide provides comprehensive coverage for all operational scenarios while maintaining enterprise-grade standards and clear execution paths.