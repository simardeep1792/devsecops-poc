# DevSecOps Proof of Concept

This project demonstrates a minimal, practical DevSecOps workflow designed for legacy-style applications that need a safe and repeatable way to deliver changes. Many systems in our organization struggle to adopt DevSecOps because they lack automated testing, safe rollout patterns, or basic supply-chain controls. This PoC provides an on-ramp. It shows how a small application can use a header-based canary strategy, automated quality gates, and essential security checks without heavy dependencies or major rewrites.

The PoC includes:

- stable and canary deployments managed by Argo Rollouts
- header-based routing using ingress-nginx
- promotion and rollback using success-rate and latency checks from Prometheus
- image scanning, SBOM generation, signing, and admission control
- GitOps workflow using Argo CD
- a step-by-step demo script that runs in under fifteen minutes

The goal is to provide a clear, repeatable pattern that teams can adopt to improve delivery frequency, reduce vulnerabilities, and increase safety without needing a full platform rebuild.