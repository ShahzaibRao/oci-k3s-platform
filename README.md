# oci-k3s-platform

Production-style Kubernetes platform on **OCI Always Free** — GitOps, eBPF networking,
zero-trust security, and tested disaster recovery. **$0/month.**

> **Status:** 🚧 Under construction — currently in planning/scaffolding phase.

## Architecture

| Layer | Choice |
|---|---|
| Cloud | OCI Always Free, `eu-frankfurt-1` (2× A1.Flex 2/12/90) |
| Load balancer | OCI Flexible LB 10 Mbps — **deferred to app go-live** (free tier) |
| Kubernetes | k3s v1.33, embedded etcd |
| CNI | Cilium (eBPF, kube-proxy replacement) + Hubble |
| Ingress | Traefik + Kubernetes Gateway API, cert-manager (Cloudflare DNS-01) |
| GitOps | ArgoCD app-of-apps (auto-sync, prune, self-heal) |
| Storage | Longhorn (replica 2) → backups to Cloudflare R2 |
| Secrets | ESO + OCI Vault (Terraform-managed, auto-sync) |
| Database | Supabase Postgres via `DATABASE_URL` contract (keep-alive + own pg_dump → R2) |
| CI/CD | GitHub Actions → Trivy → SonarCloud → Docker Hub → ArgoCD Image Updater |
| Observability | kube-prometheus-stack, Hubble, Falco |

Full design: [`DESIGN.md`](DESIGN.md) · Decision log: [`ARCHITECTURE.md`](ARCHITECTURE.md)

## Repository layout

```
├── infra/          # Terraform: network + compute modules (LB + DNS deferred to app go-live)
├── ansible/        # Roles: common, k3s_server, cilium, k3s_agent, argocd
├── gitops/
│   ├── bootstrap/  # root app (app-of-apps) — the only object applied by hand
│   └── apps/
│       ├── infra/      # platform components (each feature-flagged)
│       └── workloads/  # page-manager-pro, creatorwatch (namespace per app)
└── .github/workflows/
    ├── infra.yml   # plan on PR/push → apply (manual approval) → inventory artifact
    └── drift.yml   # every 15 min: auto-recreate missing VMs, alert other drift (planned)
```

## Disaster recovery

**RTO ≤ 30 min · RPO ≤ 24 h** — see `DESIGN.md` §12 for scenarios and rebuild order.
