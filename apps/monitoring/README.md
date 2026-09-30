# Monitoring App

kube-prometheus-stack: Prometheus + Grafana + Alertmanager + kube-state-metrics + node-exporter.

## Files

| File | Kya hai |
|------|---------|
| `Chart.yaml` | Wrapper chart (kube-prometheus-stack dependency) |
| `values.yaml` | Custom values: Grafana ingress, resource limits, retention |
| `templates/certificate.yaml` | TLS cert for `grafana.raoshahzaib.site` |

## Access Grafana

- URL: https://grafana.raoshahzaib.site
- User: `admin`
- Password: `values.yaml` mein `adminPassword` dekho (pehle login par change karo!)

## Troubleshoot

```bash
# Pods check
kubectl get pods -n monitoring

# Prometheus targets (sab UP hone chahiye)
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# → http://localhost:9090/targets

# Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Certificate status
kubectl get certificate -n monitoring
```

## metrics-server

k3s ka built-in metrics-server (`kube-system`) **delete nahi kiya**. Wo `kubectl top` ke liye hai, Prometheus se conflict nahi karta.

## Resources

Chhoti VMs ke liye tune kiya:
- Prometheus retention: 7d, memory limit 1Gi
- Grafana: 512Mi limit
- Har component par requests/limits set hain
