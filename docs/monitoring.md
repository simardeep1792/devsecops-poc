# Monitoring Guide

## Overview

This guide covers the monitoring and observability setup for the DevSecOps PoC, including Prometheus metrics collection and Grafana visualization.

## Components

### Prometheus
- **Purpose**: Metrics collection and storage
- **Namespace**: monitoring
- **Key Metrics**:
  - NGINX Ingress controller metrics
  - Kubernetes resource metrics
  - Application performance data

### Grafana
- **Purpose**: Visualization and dashboards
- **Namespace**: monitoring
- **Default Credentials**: admin / admin

## Accessing Monitoring Tools

### Grafana Dashboard

1. **Start port-forward**:
```bash
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```

2. **Access UI**: http://localhost:3000
   - Username: `admin`
   - Password: `admin`

3. **Find the dashboard**:
   - Navigate to Dashboards → Browse
   - Look for "DevSecOps PoC - Rollout Dashboard"
   - Or use direct URL: http://localhost:3000/d/devsecops-rollout

### Prometheus

1. **Start port-forward**:
```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
```

2. **Access UI**: http://localhost:9090

3. **Useful queries**:
```promql
# Request rate by service
sum(rate(nginx_ingress_controller_requests{service=~"poc-app.*"}[1m])) by (service)

# Success rate
(sum(rate(nginx_ingress_controller_requests{service=~"poc-app.*",status!~"5.."}[1m])) by (service) / sum(rate(nginx_ingress_controller_requests{service=~"poc-app.*"}[1m])) by (service)) * 100

# P95 latency
histogram_quantile(0.95, sum(rate(nginx_ingress_controller_request_duration_seconds_bucket{service=~"poc-app.*"}[1m])) by (service, le))
```

## Dashboard Panels Explained

### DevSecOps PoC - Rollout Dashboard

The dashboard includes four key panels:

1. **Request Rate by Service**
   - Shows requests per second for stable and canary services
   - Helps visualize traffic distribution during rollout
   - Expected: Higher rate for stable, gradually shifting to canary

2. **Success Rate by Service**
   - Displays percentage of non-5xx responses
   - Critical for rollout decisions (threshold: 99%)
   - Color coding: Green (>99%), Yellow (95-99%), Red (<95%)

3. **P95 Latency by Service**
   - Shows 95th percentile response time in milliseconds
   - Threshold: 500ms triggers rollback
   - Helps detect performance degradation

4. **Rollout Status**
   - Current rollout phase indicator
   - Shows progression: Stable → Step 1-4 → Promoted
   - Updates in real-time during deployments

## Metrics Used by Argo Rollouts

The AnalysisTemplate uses these Prometheus queries to make automated decisions:

### Success Rate Analysis
- **Query**: Calculates ratio of successful requests (non-5xx)
- **Threshold**: ≥99% success rate required
- **Evaluation**: Every 30 seconds, 5 times
- **Failure Action**: Automatic rollback after 2 failed checks

### Latency Analysis  
- **Query**: P95 response time using histogram quantiles
- **Threshold**: <500ms (0.5 seconds)
- **Evaluation**: Same frequency as success rate
- **Failure Action**: Automatic rollback if exceeded

## Monitoring During Rollout

1. **Pre-deployment**:
   - Ensure metrics are flowing (check Prometheus targets)
   - Verify baseline metrics are healthy

2. **During rollout**:
   - Watch Grafana dashboard for real-time updates
   - Monitor both stable and canary metrics
   - Observe traffic shift percentages

3. **Post-deployment**:
   - Confirm all traffic moved to new version
   - Verify metrics remain healthy
   - Check for any anomalies

## Troubleshooting

### No metrics appearing
```bash
# Check if ServiceMonitor is created
kubectl get servicemonitor -n poc-demo

# Verify Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets
```

### Dashboard not loading
```bash
# Check if ConfigMap exists
kubectl get cm -n monitoring | grep dashboard

# Restart Grafana to reload dashboards
kubectl rollout restart deployment prometheus-grafana -n monitoring
```

### Metrics delay
- Initial scrape interval: 30 seconds
- Allow 60-90 seconds after deployment for metrics to stabilize
- Analysis won't start until step 2 of rollout

## Future Enhancements

These features are deferred to future iterations:

1. **Alerting Rules**: Define alerts for SLO violations
2. **Custom Application Metrics**: Beyond basic HTTP metrics
3. **Distributed Tracing**: For request flow visualization
4. **Log Aggregation**: Centralized logging with Loki/ELK
5. **Business Metrics**: Application-specific KPIs

## Best Practices

1. **Set realistic thresholds** based on your SLOs
2. **Test with synthetic load** before production
3. **Monitor both technical and business metrics**
4. **Keep dashboards focused** on key indicators
5. **Document any custom queries** for team reference