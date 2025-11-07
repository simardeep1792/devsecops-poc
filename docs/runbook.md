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
kubectl argo rollouts set image poc-app poc-app=localhost:5000/poc-app:v1.1.0 -n poc-demo
```

### Monitor rollout:
```bash
kubectl argo rollouts get rollout poc-app -n poc-demo --watch
```

## Testing

### Test stable version:
```bash
curl http://poc-app.local/version
```

### Test canary version:
```bash
curl -H "x-testing: true" http://poc-app.local/version
```

## Troubleshooting

### Check rollout status:
```bash
kubectl argo rollouts status poc-app -n poc-demo
```

### View analysis run:
```bash
kubectl get analysisrun -n poc-demo
```

### Check metrics:
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```
Then visit http://localhost:9090

### View Kyverno policy violations:
```bash
kubectl get events -n poc-demo --field-selector reason=PolicyViolation
```

## Rollback

Automatic rollback happens when metrics fail. Manual rollback:
```bash
kubectl argo rollouts undo poc-app -n poc-demo
```

## Security

### Update Kyverno policy with new public key:
1. Generate new key pair in app directory
2. Extract public key: `cat app/cosign.pub`
3. Update policies/require-signed.yaml
4. Apply: `kubectl apply -f policies/require-signed.yaml`