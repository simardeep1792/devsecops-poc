# DevSecOps PoC

Enterprise-grade progressive deployment with dual-URL strategy for zero-risk canary releases and mandatory QA approval gates.

## What This Does

This PoC implements **always-available QA testing** with **progressive production rollouts**:

### The Dual-URL Strategy
- **Production URL** (http://poc-app.local) - Always shows stable version with progressive traffic shifting
- **QA URL** (http://poc-app-qa.local) - Always shows canary version for testing (never returns 503)

### The Improved Workflow
1. **Deploy canary with guaranteed pods** - Minimum 1 canary replica always running for QA
2. **QA tests immediately** - QA URL works instantly, no waiting for traffic shifts
3. **Progressive production rollout** - After QA approval: 0% → 10% → 20% → 50% → 100%
4. **Instant rollback** - Emergency rollback available at any stage

**Key Innovation**: QA URL is decoupled from production traffic weights - QA always gets 100% canary while production follows safe progressive rollout.

## Overview

This proof-of-concept addresses a critical organizational challenge: establishing a viable path to higher delivery velocity for legacy applications so they can participate in the DevSecOps world. Without this capability, organizations risk creating a bi-modal IT environment with modern systems receiving continuous security updates while core legacy systems accumulate vulnerabilities on unsupported software.

> "If the rate of change on the outside exceeds the rate of change on the inside, the end is near." - Jack Welch

DevSecOps enables security at the rate of change. This PoC demonstrates how ALL systems, including legacy applications lacking automated testing, can adopt progressive deployment patterns to:

- Increase delivery cadence to pay down technical debt
- Reduce vulnerability exposure windows
- Encourage incremental automation
- Enable gradual introduction of security and quality testing

### Key Capabilities

- **Progressive Deployment**: Dual-URL routing with separate QA endpoint for safe canary validation
- **Traffic Isolation**: Production traffic always hits stable URL while QA validates via dedicated QA URL
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
| **NGINX Ingress** | Traffic management | Routes traffic to stable and QA URLs |
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

## Quick Start Guide

### What You'll See

- **Production URL** (http://poc-app.local) - GREEN background (stable version)
- **QA URL** (http://poc-app-qa.local) - AMBER background (canary version, always available)

The dual-URL strategy ensures QA can always test while production remains safe!

## Setup Instructions

### 1. Environment Setup

```bash
# Check prerequisites
make prerequisites

# Create cluster and install components
make setup

# Add hostnames to /etc/hosts
echo "127.0.0.1 poc-app.local poc-app-qa.local" | sudo tee -a /etc/hosts
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

### 3. Test the Initial Deployment

**Step 1: Open the production URL in your browser**
- Go to: http://poc-app.local
- You should see a **GREEN** background with "STABLE RELEASE"

**Step 2: Verify the QA URL status**
- Go to: http://poc-app-qa.local
- Initially shows the stable version (GREEN) since no canary is deployed yet

### 4. Deploy a Canary Version (With Always-Available QA)

**Step 1: Deploy version 1.1.0**
```bash
make deploy-canary VERSION=v1.1.0
```

**Step 2: Verify canary deployment**
```bash
make qa-status
```
Shows canary pods running and endpoints available

**Step 3: QA Testing Phase**
Current state:
- **Production URL** (http://poc-app.local) - **GREEN** (100% stable v1.0)
- **QA URL** (http://poc-app-qa.local) - **AMBER** (100% canary v1.1.0)
- **Canary pods**: Minimum 1 replica always running
- **Production traffic**: 0% to canary

**Step 4: Progressive Production Rollout**
After QA validates the canary version:
```bash
make promote-10   # Start with 10% production traffic
make promote-20   # Increase to 20% production traffic
make promote-50   # Increase to 50% production traffic
make promote-100  # Complete rollout to 100%
```

**Step 5: Monitor after QA approval**
```bash
make dashboards  # Opens Grafana at http://localhost:3000 (admin/admin)
```

### 5. Complete the Rollout

After each promotion step, monitor metrics before proceeding:

```bash
make rollout-status  # Check current traffic distribution
```

Final state after 100% promotion:
- http://poc-app.local - Shows v1.1.0 **GREEN** (new stable)
- http://poc-app-qa.local - Shows v1.1.0 **GREEN** (awaiting next canary)

**Visual Indicators:**
- **GREEN background** = Stable/Production version
- **AMBER background** = Canary version (QA testing)
- **Traffic percentage** = Shown in rollout status

### 6. Test Auto-Rollback

**Deploy a bad version (v1.2.0 has 30% errors):**
```bash
make deploy-canary VERSION=v1.2.0
make promote-20  # Move to 20% - will auto-rollback when metrics fail

# Or emergency rollback:
make rollback
```

Watch it auto-rollback in ~2-3 minutes when metrics fail!

## Application Endpoints

| Endpoint | Purpose | Parameters |
|----------|---------|------------|
| `/health` | Health check | None |
| `/version` | Version information | None |
| `/work` | CPU load simulation | `?delay=100` (ms) |
| `/` | Status summary | None |

### Traffic Routing

**Dual-URL Strategy with Decoupled Routing**:
- **Production URL**: `http://poc-app.local` - Follows progressive traffic weights (0% → 10% → 20% → 50% → 100%)
- **QA URL**: `http://poc-app-qa.local` - Always routes to canary pods (100% canary traffic)

### Key Architecture Improvements

**1. Guaranteed Canary Availability:**
- `setCanaryScale: replicas: 1` ensures minimum 1 canary pod
- `scaleDownDelaySeconds: 600` keeps pods alive for 10 minutes
- No more 503 errors on QA URL

**2. Independent QA Testing:**
- QA URL bypasses traffic weight controls
- QA always gets 100% canary traffic
- Production traffic follows safe progressive rollout

**3. Progressive Traffic Shifting:**
```
Step 1: 0% production, 100% QA → Canary validation
Step 2: 10% production, 100% QA → Initial production exposure  
Step 3: 20% production, 100% QA → Increased confidence
Step 4: 50% production, 100% QA → Half production traffic
Step 5: 100% production → Full rollout complete
```

**Visual Indicators:**
- **GREEN background** = Stable/Production version
- **AMBER background** = Canary version (QA testing)
- **Traffic split** = Managed by Argo Rollouts progressively

## Monitoring and Observability

### Application Metrics

- Success rate monitoring for deployment decisions
- Latency tracking for performance validation
- Error rate analysis for rollback triggers

### Access Dashboards

```bash
# Open all dashboards
make dashboards
```

This opens:
- **Grafana**: http://localhost:3000 (admin/admin)
- **Argo CD**: https://localhost:8080 (admin/see command output)
- **Prometheus**: http://localhost:9090

### Dashboard Credentials

| Dashboard | Username | Password |
|-----------|----------|----------|
| Grafana | admin | admin |
| Argo CD | admin | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |
| Prometheus | - | No auth required |

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

## Operational Commands

### QA Operations

| Command | Purpose |
|---------|---------|
| `make deploy-canary VERSION=v1.1.0` | Deploy canary with guaranteed QA access |
| `make qa-status` | Check QA environment and canary pod status |
| `make promote-10` | Start production traffic at 10% |
| `make promote-20` | Increase production traffic to 20% |
| `make promote-50` | Increase production traffic to 50% |
| `make promote-100` | Complete rollout to 100% |
| `make rollback` | Emergency rollback to stable version |
| `make rollout-status` | Show detailed rollout progress |

### Step-by-Step Promotion Workflow

**1. Deploy new canary version:**
```bash
make deploy-canary VERSION=v1.1.0
```

**2. Verify canary environment:**
```bash
make qa-status  # Shows canary pods and endpoints
make rollout-status  # Shows SetWeight: 0, ActualWeight: 0
```

**3. QA Validation Phase:**
- Production URL: http://poc-app.local - **GREEN** (100% stable v1.0)
- QA URL: http://poc-app-qa.local - **AMBER** (100% canary v1.1)
- Canary pods: Guaranteed minimum 1 replica running

**4. Progressive Production Rollout:**
```bash
make promote-10   # After QA approval: 10% production traffic
make promote-20   # Continue testing: 20% production traffic
make promote-50   # Increased confidence: 50% production traffic
make promote-100  # Full rollout: 100% production traffic
```

**5. Monitor throughout deployment:**
```bash
make dashboards     # Grafana metrics
make rollout-status # Current traffic distribution
```

**Each promotion step requires explicit QA approval!**

### Safety Features

**Dual-URL Advantages:**
- **Always-available QA**: Canary pods guaranteed via `setCanaryScale`
- **Zero 503 errors**: QA URL works immediately after deployment
- **Independent testing**: QA validation decoupled from production traffic
- **Progressive safety**: 0% → 10% → 20% → 50% → 100% with gates

**Rollback Options:**
- `make rollback`: Immediate abort and undo
- Manual traffic reduction via `kubectl argo rollouts`
- Automatic rollback on metric failures (if analysis enabled)

## Directory Structure

```text
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
| QA URL returns 404 | Normal when no canary is active |
| Analysis errors | Fixed queries handle missing metrics |
| Argo CD shows Degraded | Usually due to temporary analysis runs |

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

This PoC demonstrates an enterprise-ready path where legacy applications can:

1. **Start Immediately**: Deploy with guaranteed QA access (no 503 errors)
2. **Test Independently**: QA validates without affecting production traffic
3. **Progress Safely**: 10% → 20% → 50% → 100% with approval gates
4. **Rollback Instantly**: Emergency rollback always available

The enhanced dual-URL strategy delivers:

- **Always-available QA URL**: Minimum canary replicas guarantee access
- **Decoupled traffic control**: QA gets 100% canary while production progresses safely
- **Progressive rollout**: Start at 10% for safer initial exposure
- **Manual approval gates**: Human validation at each step

## Contributing

This PoC demonstrates patterns suitable for enterprise adoption. Key principles:

1. **Incremental Adoption**: Start with manual QA validation, add automation over time
2. **Safety First**: Production URL isolated from canary versions
3. **Metrics-Driven**: Automated rollback based on performance data
4. **Human-in-the-Loop**: QA approval required at each step

The implementation provides a foundation for bringing ALL systems into the DevSecOps fold, preventing the creation of a two-tier IT environment where only new systems benefit from modern practices.
