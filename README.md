# DevSecOps PoC

Enterprise-grade progressive deployment demonstration with integrated security controls, automated analysis, and GitOps workflows.

## Overview

This proof-of-concept addresses a critical organizational challenge: establishing a viable path to higher delivery velocity for legacy applications so they can participate in the DevSecOps world. Without this capability, organizations risk creating a bi-modal IT environment with modern systems receiving continuous security updates while core legacy systems accumulate vulnerabilities on unsupported software.

> "If the rate of change on the outside exceeds the rate of change on the inside, the end is near." - Jack Welch

DevSecOps enables security at the rate of change. This PoC demonstrates how ALL systems, including legacy applications lacking automated testing, can adopt progressive deployment patterns to:

- Increase delivery cadence to pay down technical debt
- Reduce vulnerability exposure windows
- Encourage incremental automation
- Enable gradual introduction of security and quality testing

### Key Capabilities

- **Progressive Deployment**: Header-based canary routing allowing QA teams to validate changes with x-testing headers
- **Traffic Mirroring Pattern**: 100% of production traffic remains on stable version while canary receives only test traffic
- **Automated Promotion**: After sufficient successful responses from canary, automatic replacement of stable version
- **Security Integration**: Vulnerability scanning and SBOM generation without blocking initial adoption
- **Metrics-Driven Decisions**: Automatic rollback based on error rates or latency, requiring no manual intervention

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │   CI/CD         │    │   Kubernetes    │
│                 │────│                 │────│                 │
│ - Code Changes  │    │ - Image Build   │    │ - Argo Rollouts │
│ - Git Push      │    │ - Security Scan │    │ - Canary Route  │
└─────────────────┘    │ - SBOM Generate │    │ - Auto Rollback │
                       └─────────────────┘    └─────────────────┘
                                │
                       ┌─────────────────┐
                       │   Monitoring    │
                       │                 │
                       │ - Prometheus    │
                       │ - Analysis      │
                       └─────────────────┘
```

### Components

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| **Argo Rollouts** | Progressive delivery controller | Header-based canary with metrics analysis |
| **NGINX Ingress** | Traffic management | Routes traffic based on x-testing header |
| **Prometheus** | Metrics collection | Success rate and latency monitoring |
| **Argo CD** | GitOps controller | Manages application configurations |
| **Trivy** | Security scanning | Container vulnerability assessment |

## Prerequisites

### Required Tools

```bash
# Verify installations
docker --version          # >= 20.0
kubectl version --client  # >= 1.20
kind version              # >= 0.11
helm version              # >= 3.0
```

### System Requirements

- macOS or Linux
- 8GB RAM available for Docker
- Port 80 available for ingress

## Quick Start

### 1. Environment Setup

```bash
# Check prerequisites
make prerequisites

# Create cluster and install components
make setup

# Add hostnames to /etc/hosts
echo "127.0.0.1 poc-app.local canary.poc-app.local" | sudo tee -a /etc/hosts
```

### 2. Application Deployment

```bash
# Build and push application
make build

# Deploy to cluster
make deploy

# Verify deployment
make status
```

### 3. Run Demonstrations

```bash
# Full interactive demo
make demo

# Quick endpoint test
make demo-quick

# Live monitoring
make demo-monitor

# Open dashboards
make dashboards
```

## Usage Scenarios

### Scenario 1: Initial Deployment

```bash
make setup build deploy
make test
```

Demonstrates: Basic application deployment with security scanning

### Scenario 2: Canary Deployment

```bash
make demo-canary
```

Demonstrates: Progressive rollout with header-based traffic splitting

### Scenario 3: Automated Rollback

```bash
# Trigger deployment with issues
./scripts/build-and-push.sh v1.2.0  # High error rate version
kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:v1.2.0 -n poc-demo
```

Demonstrates: Automatic rollback when metrics indicate problems

### Scenario 4: Security Validation

```bash
# View security scan results
cat sbom-v1.0.0.json | jq '.packages[0:5]'

# Check deployment policies
kubectl describe rollout poc-app -n poc-demo
```

Demonstrates: Security scanning integration and policy enforcement

## Application Endpoints

| Endpoint | Purpose | Parameters |
|----------|---------|------------|
| `/health` | Health check | None |
| `/version` | Version information | None |
| `/work` | CPU load simulation | `?delay=100` (ms) |
| `/` | Status summary | None |

### Traffic Routing

- **Production Traffic**: `curl http://poc-app.local/version`
- **Canary Traffic**: `curl http://canary.poc-app.local/version`

## Monitoring and Observability

### Application Metrics

- Success rate monitoring for deployment decisions
- Latency tracking for performance validation
- Error rate analysis for rollback triggers

### Access Dashboards

```bash
# Argo CD (GitOps)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080

# Prometheus (Metrics)  
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
# http://localhost:9090
```

### Credentials

- **Argo CD Username**: admin
- **Argo CD Password**: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

## Security Features

### Vulnerability Scanning

Trivy performs comprehensive security analysis:
- OS package vulnerabilities
- Language-specific dependency scanning
- Configuration security assessment

### Software Bill of Materials

Automated SBOM generation provides:
- Complete dependency inventory
- License compliance tracking  
- Security vulnerability mapping

## Directory Structure

```
├── Makefile                 # Primary interface for all operations
├── README.md               # This documentation
├── app/                    # Application source code
│   ├── Dockerfile         # Container definition
│   ├── go.mod            # Go dependencies
│   └── main.go           # Application logic
├── k8s/                   # Kubernetes manifests
│   ├── base/             # Base configuration
│   └── local/            # Local environment overlay
├── scripts/              # Automation scripts
│   ├── setup-local.sh    # Environment setup
│   ├── build-and-push.sh # Build automation
│   ├── demo.sh           # Interactive demonstrations
│   └── show-apps.sh      # Application monitoring
└── argocd/               # GitOps configuration
    └── application.yaml  # Argo CD application definition
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Cluster not accessible | Run `make setup` |
| Application not responding | Check `make status` |
| Image pull failures | Verify Docker Hub connectivity |
| Demo script failures | Run `make prerequisites` |

### Diagnostic Commands

```bash
# Cluster status
kubectl cluster-info

# Application status  
kubectl get pods -n poc-demo

# Rollout status
kubectl argo rollouts get rollout poc-app -n poc-demo

# Application logs
make logs
```

### Reset Environment

```bash
# Complete reset
make clean setup build deploy
```

## Development

### Adding New Versions

```bash
# Build with specific version
./scripts/build-and-push.sh v1.1.0

# Deploy new version
kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:v1.1.0 -n poc-demo
```

### Customizing Behavior

Application supports environment variables:
- `ERROR_RATE`: Percentage of requests that return errors (0-100)
- `LATENCY_MS`: Artificial latency in milliseconds

### Testing Scenarios

The application includes built-in test scenarios:
- `v1.2.0`: High error rate (30%)
- `v1.3.0`: High latency (2000ms)

These demonstrate automatic rollback capabilities.

## Why This Matters for Legacy Applications

Traditional DevSecOps implementations often require:
- Comprehensive automated testing
- Modern CI/CD pipelines
- Cloud-native architectures
- Skilled DevOps teams

This creates a barrier for legacy applications, leading to:
- Extended vulnerability windows
- Inability to patch quickly
- Growing technical debt
- Increased security risk

This PoC demonstrates an alternative path where legacy applications can:

1. **Start Small**: Adopt header-based canary without changing architecture
2. **Build Confidence**: Use QA team validation instead of automated tests initially
3. **Increase Velocity**: Deploy more frequently with safety mechanisms
4. **Add Automation**: Gradually introduce automated testing as confidence grows

The traffic mirroring approach ensures:
- Zero impact to production users during validation
- QA teams control their own testing pace
- Automatic promotion only after proven success
- Immediate rollback if issues detected

## Contributing

This PoC demonstrates patterns suitable for enterprise adoption. Key principles:

1. **Incremental Adoption**: Start with manual QA validation, add automation over time
2. **Safety First**: Production traffic never touches unproven versions
3. **Metrics-Driven**: Decisions based on actual performance data
4. **Legacy-Friendly**: Minimal requirements for initial adoption

The implementation provides a foundation for bringing ALL systems into the DevSecOps fold, preventing the creation of a two-tier IT environment where only new systems benefit from modern practices.