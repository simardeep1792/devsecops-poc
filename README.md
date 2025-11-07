# DevSecOps Proof of Concept

This project demonstrates a minimal, practical DevSecOps workflow designed for legacy-style applications that need a safe and repeatable way to deliver changes.

## Quick Start

1. **Setup local environment:**
   ```bash
   ./scripts/setup-local.sh
   ```

2. **Add to /etc/hosts:**
   ```
   127.0.0.1 poc-app.local
   ```

3. **Build and deploy initial version:**
   ```bash
   ./scripts/build-and-push.sh v1.0.0
   kubectl apply -k k8s/base/
   ```

4. **Run the demo:**
   ```bash
   ./scripts/demo.sh
   ```

## Project Structure

- `app/` - Go application with version-specific behaviors
- `k8s/` - Kubernetes manifests with Kustomize overlays
- `scripts/` - Automation scripts for setup and demo
- `policies/` - Kyverno security policies
- `docs/` - Detailed documentation

## Key Features

- **Canary Deployments**: Argo Rollouts manages progressive delivery
- **Header-based Routing**: Test with `x-testing: true` header
- **Automatic Rollback**: Fails on high error rate or latency
- **Security Scanning**: Trivy scans for vulnerabilities
- **Image Signing**: Cosign ensures image integrity
- **SBOM Generation**: Syft creates software bill of materials

## Documentation

- [Runbook](docs/runbook.md) - Operations guide
- [Adoption Guide](docs/adoption.md) - How to migrate legacy apps
- [Full Documentation](docs/README.md) - Detailed overview

## First-time Setup Note

After running `build-and-push.sh` for the first time, update the Kyverno policy with your public key:

1. Copy the contents of `app/cosign.pub`
2. Edit `policies/require-signed.yaml`
3. Replace the placeholder public key
4. Apply: `kubectl apply -f policies/require-signed.yaml`