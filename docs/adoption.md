# Legacy Application Adoption Guide

## Overview

This guide helps teams adopt the DevSecOps practices demonstrated in this PoC for their existing applications.

## Prerequisites Assessment

Before adopting this pattern, ensure your application:
- Can be containerized
- Has clear health check endpoints
- Can handle multiple instances running simultaneously
- Has measurable success metrics

## Step 1: Application Preparation

1. **Add health endpoints**:
   - `/health` - Basic liveness check
   - `/ready` - Readiness check
   - `/metrics` - Optional Prometheus metrics

2. **Containerize the application**:
   - Create multi-stage Dockerfile
   - Minimize final image size
   - Run as non-root user

3. **Version management**:
   - Use semantic versioning
   - Embed version in application
   - Log version on startup

## Step 2: Define Success Metrics

Choose metrics that represent your application's health:
- Request success rate (typically > 99%)
- Response time (P95 latency)
- Business-specific metrics

## Step 3: Implement Header-Based Testing

1. Identify test users or teams
2. Document the x-testing header usage
3. Create test scenarios for validation

## Step 4: Security Integration

1. **Scanning**:
   - Integrate Trivy in CI/CD pipeline
   - Set acceptable CVE thresholds
   - Block on critical vulnerabilities

2. **Signing**:
   - Generate team-specific signing keys
   - Implement signing in build process
   - Update admission policies

3. **SBOM**:
   - Generate with each build
   - Store in artifact repository
   - Include in compliance reports

## Step 5: Gradual Rollout

Start with:
- Non-critical applications
- Low traffic periods
- Conservative thresholds (99.9% success rate)

Then expand to:
- Higher traffic applications
- Business hours deployment
- Adjusted thresholds based on SLOs

## Migration Checklist

- [ ] Application has health endpoints
- [ ] Dockerfile created and optimized
- [ ] Local testing completed
- [ ] Metrics identified and instrumented
- [ ] Security scanning integrated
- [ ] Image signing implemented
- [ ] Rollout strategy defined
- [ ] Runbook created for team
- [ ] Team trained on new workflow

## Common Pitfalls

1. **Stateful applications**: Ensure proper session handling
2. **Database migrations**: Separate from code deployment
3. **Configuration changes**: Use ConfigMaps/Secrets
4. **Dependencies**: Ensure backward compatibility

## Support

- Review this PoC's demo script
- Attend DevSecOps office hours
- Contact platform team for assistance