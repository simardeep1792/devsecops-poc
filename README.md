# DevSecOps PoC

Enterprise-grade progressive deployment demonstration with integrated security controls, automated analysis, and GitOps workflows.

## What This Does

This PoC implements **zero-risk canary deployments** with **mandatory QA approval**:

### The Two URLs
- **Production URL** (http://poc-app.local) - Your users always see stable (GREEN UI)
- **QA URL** (http://poc-app-qa.local) - Internal QA testing only (AMBER UI)

### The Approval Process
1. **Deploy at 0% traffic** - Canary runs but gets ZERO production traffic
2. **QA validates internally** - Uses QA URL to test new version
3. **QA approves manually** - Only then does production traffic start flowing
4. **Gradual promotion** - 0% → 20% → 50% → 80% → 100% with approval at each step

**Critical Safety**: Production traffic NEVER touches canary until QA explicitly approves.

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

- **Production URL** (http://poc-app.local) - Always GREEN background, never shows canary
- **QA URL** (http://poc-app-qa.local) - AMBER background during rollout, 404 when idle

The system ensures production users NEVER see untested versions!

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

**Step 2: Try the QA URL**
- Go to: http://poc-app-qa.local
- You should see "404 Not Found" (this is normal - no canary exists yet)

### 4. Deploy a Canary Version (Zero Production Risk)

**Step 1: Deploy version 1.1.0 (0% traffic)**
```bash
make deploy-canary VERSION=v1.1.0
```

**Step 2: Verify rollout is paused at 0% (QA-only phase)**
```bash
make rollout-status
```
Should show: "Paused at step 1/8, SetWeight: 0, ActualWeight: 0"

**Step 3: QA Internal Testing (CRITICAL - No production impact)**
At this point:
- **Production URL** (http://poc-app.local) - Still **GREEN** (all production traffic)
- **QA URL** (http://poc-app-qa.local) - Now **AMBER** (QA testing only)
- **ZERO production traffic** goes to canary

**Step 4: QA Approval Gate**
QA team validates the canary version thoroughly via QA URL. Only when satisfied:
```bash
make promote-20  # This starts sending 20% production traffic to canary
```

**Step 5: Monitor after QA approval**
```bash
make dashboards  # Opens Grafana at http://localhost:3000 (admin/admin)
```

### 5. Complete the Rollout

Promote through each step with QA approval:
```bash
make promote-50   # QA approves: Goes to 50%
make promote-80   # QA approves: Goes to 80%
make promote-100  # QA final approval: Goes to 100% - canary becomes new stable
```

After final promotion:
- http://poc-app.local - Shows v1.1.0 **GREEN** (now stable)
- http://poc-app-qa.local - Back to 404 (no active canary)

**Color Changes:**
- During rollout: QA URL shows **AMBER** background (canary)
- After 100%: New version becomes stable and shows **GREEN** background

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

**Dual-URL Routing** (production-safe approach):
- **Stable URL**: `http://poc-app.local` - Always shows green UI (production)
- **QA URL**: `http://poc-app-qa.local` - Shows amber UI during rollout (QA only)

### The 0% Traffic Phase (Critical QA Gate)

When a canary is deployed, it starts at **0% traffic**. This means:

**What happens:**
- Canary pods are created and running
- QA URL (poc-app-qa.local) routes to canary pods
- Production URL (poc-app.local) still routes 100% to stable
- **ZERO production users see the canary**

**QA Validation:**
- QA team accesses http://poc-app-qa.local (internal URL)
- Thoroughly tests the new version (AMBER background)
- Can run full test suites, manual testing, smoke tests
- Production continues normally on stable version

**Only after QA approval does production traffic start flowing to canary!**

**Testing in Browser:**
1. http://poc-app.local - Always shows stable (GREEN background)
2. http://poc-app-qa.local - Shows canary during rollout (AMBER) or 404 when idle

**Visual Indicators:**
- **GREEN background** = Stable/Production version
- **AMBER background** = Canary version (QA validation only)
- **404 error** = No active canary deployment

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
| `make promote` | Approve and promote to next rollout step |
| `make rollback` | Immediately rollback to stable version |
| `make pause-rollout` | Pause rollout at current weight for investigation |
| `make rollout-status` | Show detailed rollout status and analysis runs |

### Step-by-Step Promotion Workflow (With Approval Gates)

**1. Deploy new version (creates canary at 0% traffic):**
```bash
kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:v1.1.0 -n poc-demo
```

**2. Verify canary is isolated (NO production impact):**
```bash
make rollout-status  # Should show: SetWeight: 0, ActualWeight: 0
```

**3. QA Internal Validation Phase:**
- Production URL: http://poc-app.local - Still GREEN (100% stable traffic)
- QA URL: http://poc-app-qa.local - Now AMBER (canary for testing)
- **QA must thoroughly test the canary via QA URL**

**4. QA Approval Gate #1 (Start production traffic):**
```bash
make promote  # ONLY after QA approves - moves 0% → 20%
```

**5. Monitor metrics and continue approvals:**
```bash
make dashboards  # Watch metrics in Grafana
make promote     # QA approves: 20% → 50%
make promote     # QA approves: 50% → 80%
make promote     # QA approves: 80% → 100% (canary becomes stable)
```

**Each `make promote` requires explicit QA approval - no automation!**

### Safety Gates

**QA Approval Gates:**
- **Gate 1**: QA validates at QA URL before ANY production traffic (0% phase)
- **Gate 2**: QA approves each traffic increase (20%, 50%, 80%, 100%)
- **No automation** - every promotion requires explicit QA approval

**Automatic Protection:**
- Metrics must pass (99% success, <500ms latency) at each step
- Any metric failure triggers immediate automatic rollback
- Production traffic instantly reverts to stable on failure

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

This PoC demonstrates an alternative path where legacy applications can:

1. **Start Small**: Adopt dual-URL routing without changing architecture
2. **Build Confidence**: QA validates via dedicated URL, production stays safe
3. **Increase Velocity**: Deploy more frequently with metric-based safety
4. **Add Automation**: Gradually introduce automated testing as confidence grows

The dual-URL approach ensures:
- Production URL always serves stable version
- QA URL provides isolated canary validation
- Manual approval required for each promotion step
- Automatic rollback if metrics fail at any point

## Contributing

This PoC demonstrates patterns suitable for enterprise adoption. Key principles:

1. **Incremental Adoption**: Start with manual QA validation, add automation over time
2. **Safety First**: Production URL isolated from canary versions
3. **Metrics-Driven**: Automated rollback based on performance data
4. **Human-in-the-Loop**: QA approval required at each step

The implementation provides a foundation for bringing ALL systems into the DevSecOps fold, preventing the creation of a two-tier IT environment where only new systems benefit from modern practices.
