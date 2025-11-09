# DevSecOps PoC Runbook

## Prerequisites

- Docker Desktop or Docker Engine
- kubectl
- helm
- kind
- Basic understanding of Kubernetes

## Initial Setup

1. Clone the repository
2. Run the setup script:
   ```bash
   make setup
   # or
   ./scripts/setup-local.sh
   ```
3. Add to /etc/hosts:
   ```
   127.0.0.1 poc-app.local
   ```

## Building and Deploying

### Build a new version:
```bash
./scripts/build-and-push.sh v1.1.0
```

### Deploy via Argo Rollouts:
```bash
kubectl argo rollouts set image poc-app poc-app=simardeep1792/poc-app:v1.1.0 -n poc-demo
```

### Monitor rollout:
```bash
kubectl argo rollouts get rollout poc-app -n poc-demo --watch
```

## Testing

### Test stable version:
```bash
# View in browser
curl http://poc-app.local/

# Check version endpoint
curl http://poc-app.local/version
```

### Test canary version:
```bash
# View canary with header
curl -H "x-testing: true" http://poc-app.local/

# Check canary version
curl -H "x-testing: true" http://poc-app.local/version
```

### Generate load for testing:
```bash
./scripts/generate-load.sh
# Shows live stats with 80/20 traffic split
# Press Ctrl+C to stop
```

## Monitoring

### Access Grafana Dashboard:
```bash
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```
- URL: http://localhost:3000
- Username: admin
- Password: admin
- Dashboard: "DevSecOps PoC - Rollout Dashboard"

### Access Prometheus:
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```
- URL: http://localhost:9090

### Access Argo CD:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
- URL: https://localhost:8080
- Username: admin
- Password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

## Validation

### Run full validation:
```bash
make validate
# or
./scripts/validate.sh
```

### Quick status check:
```bash
make status
# or
./scripts/show-apps.sh status
```

## Troubleshooting

### Check rollout status:
```bash
kubectl argo rollouts status poc-app -n poc-demo
```

### View analysis runs:
```bash
kubectl get analysisrun -n poc-demo
kubectl describe analysisrun -n poc-demo
```

### View pod logs:
```bash
kubectl logs -n poc-demo -l app=poc-app --tail=100
```

### Check ingress configuration:
```bash
kubectl get ingress -n poc-demo
kubectl describe ingress -n poc-demo
```

### Verify metrics collection:
```bash
# Check if NGINX metrics are available
curl -s http://localhost:9090/api/v1/query?query=nginx_ingress_controller_requests
```

## Rollback

Automatic rollback happens when metrics fail. Manual rollback:
```bash
kubectl argo rollouts undo poc-app -n poc-demo
```

Abort a canary deployment:
```bash
kubectl argo rollouts abort poc-app -n poc-demo
```

## Common Operations

### Restart from scratch:
```bash
make reset
# This runs: clean, setup, build, deploy
```

### Run full demo:
```bash
make demo
```

### Open all dashboards:
```bash
make dashboards
```

### Check prerequisites:
```bash
make prerequisites
```

## Image Management

### List available versions:
```bash
docker images simardeep1792/poc-app
```

### Pull a specific version:
```bash
docker pull simardeep1792/poc-app:v1.1.0
```

### Check SBOM for a version:
```bash
cat sbom-v1.1.0.json | jq '.packages[0:5]'
```

## Tips

1. **Wait for metrics**: After deployment, wait 60-90 seconds before the analysis starts
2. **Header routing**: Always use `x-testing: true` header to test canary
3. **Load generation**: Run load generator during demos to ensure metrics are populated
4. **Validation**: Run `make validate` after setup to ensure everything is ready

## Emergency Procedures

### If rollout is stuck:
```bash
kubectl argo rollouts retry rollout poc-app -n poc-demo
```

### If pods won't start:
```bash
kubectl describe pod -n poc-demo -l app=poc-app
kubectl events -n poc-demo
```

### Reset application state:
```bash
kubectl delete -k k8s/base/
kubectl apply -k k8s/base/
```