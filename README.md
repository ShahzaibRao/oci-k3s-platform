# oci-k3s-platform

Production-style Kubernetes platform on **OCI Always Free** — GitOps, SSO, monitoring,
and tested disaster recovery. **$0/month.**

> **Status:** ✅ **LIVE in production** — serving real traffic since 2026-10-02.

## Live URLs

| Service | URL | Description |
|---------|-----|-------------|
| 🏠 Homepage | https://homepage.raoshahzaib.site | Cluster dashboard — all services |
| 📊 Grafana | https://grafana.raoshahzaib.site | Metrics & SRE dashboards (Keycloak + Google SSO) |
| 🔄 ArgoCD | https://argocd.raoshahzaib.site | GitOps deployments |
| 🔐 Keycloak | https://auth.raoshahzaib.site | SSO Identity Provider (v26.0.8) |
| 🚀 CreatorWatch | https://cw.raoshahzaib.site | License server ($29/yr SaaS) |

## Architecture

| Layer | Choice |
|---|---|
| Cloud | OCI Always Free, `eu-frankfurt-1` (2× A1.Flex 2/12/90) |
| Load balancer | OCI Flexible LB 10 Mbps — **LIVE** (`92.5.123.40`) |
| Kubernetes | k3s v1.33, embedded etcd |
| CNI | k3s default (flannel + kube-proxy) — Cilium dropped after pod-to-API routing saga |
| Ingress | Traefik, cert-manager (Cloudflare DNS-01) |
| GitOps | ArgoCD app-of-apps (auto-sync, prune, self-heal) |
| Secrets | ESO + OCI Vault (Terraform-managed, auto-sync) |
| SSO | Keycloak 26.0.8 — Grafana (Keycloak + Google OAuth), ArgoCD (paused) |
| Database | Supabase Postgres via `DATABASE_URL` contract |
| CI/CD | GitHub Actions → Docker Hub → ArgoCD |
| Observability | kube-prometheus-stack (Prometheus + Grafana + Alertmanager) |
| Backups | Velero → R2 (daily, TTL 30d) — **restore tested ✅** |
| Homepage | gethomepage.dev v2.4.0 — cluster landing page |

Full design: [`DESIGN.md`](DESIGN.md) · Decision log: [`ARCHITECTURE.md`](ARCHITECTURE.md) · Setup: [`SETUP.md`](SETUP.md)

## Repository layout

```
├── infra/          # Terraform: network + compute + LB + Vault secrets
├── ansible/        # Roles: common, k3s_server, k3s_agent, argocd
├── apps/           # Per-app manifests (each app: deployment + service + ingress + cert)
│   ├── argocd/
│   ├── cert-manager/
│   ├── cloudflare/
│   ├── creatorwatch/
│   ├── external-secrets/
│   ├── homepage/
│   ├── keycloak/
│   └── monitoring/  # kube-prometheus-stack
├── argocd/apps/    # ApplicationSet (app-of-apps)
└── .github/workflows/
    ├── infra.yml   # Terraform plan/apply
    └── ansible.yml # k3s + ArgoCD bootstrap
```

## Infrastructure

| Node | Public IP | Private IP |
|------|-----------|------------|
| k3s-server | 92.5.175.220 | 10.0.1.10 |
| k3s-agent | 130.61.30.156 | 10.0.1.11 |
| OCI LB | 92.5.123.40 | — |

## Disaster recovery

**RTO ≤ 30 min · RPO ≤ 24 h** — tested end-to-end 2026-10-01 (full VM rebuild).
Velero restore tested 2026-10-03 ✅. See `DESIGN.md` §12.
