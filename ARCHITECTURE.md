# OCI k3s Production Platform — Architecture

> Status: ✅ **PRODUCTION** — live since 2026-10-02, serving real traffic.
> Last updated: 2026-10-05 (v7: Keycloak SSO, Homepage, Grafana Google OAuth, Velero restore tested).

## Goal
Production-style Kubernetes platform on OCI Always Free, hosting real apps
(CreatorWatch) for real users. Recruiter-visible: GitOps, SSO, TLS, monitoring,
backups, disaster recovery, DevSecOps at every layer.

## Live Services
| Service | URL | Status |
|---------|-----|--------|
| Homepage | https://homepage.raoshahzaib.site | ✅ Live |
| Grafana | https://grafana.raoshahzaib.site | ✅ Live (Keycloak + Google SSO) |
| ArgoCD | https://argocd.raoshahzaib.site | ✅ Live (SSO paused) |
| Keycloak | https://auth.raoshahzaib.site | ✅ Live (v26.0.8) |
| CreatorWatch | https://cw.raoshahzaib.site | ✅ Live |

## Non-negotiables
- 100% free-tier only: OCI Always Free (4 OCPU / 24 GB RAM / 200 GB boot),
  Cloudflare R2 free allowance, all CNCF/OSS components (no paid SaaS).
- SSH kept open for now via admin_cidr (hardening deferred, one variable away).
- Everything declarative in git. Rebuild from zero in ~20–30 min.

## Repository layout (mono-repo)
```
.
├── infra/          # Terraform: network + compute + LB + OCI Vault secrets
├── ansible/        # Roles: common, k3s_server, k3s_agent, argocd
├── apps/           # Per-app: deployment + service + ingress + certificate
│   ├── argocd/
│   ├── cert-manager/
│   ├── cloudflare/
│   ├── creatorwatch/
│   ├── external-secrets/
│   ├── homepage/
│   ├── keycloak/
│   └── monitoring/
├── argocd/apps/    # ApplicationSet (app-of-apps pattern)
└── .github/workflows/
    ├── infra.yml   # terraform plan/apply
    └── ansible.yml # k3s + ArgoCD bootstrap
```

## Decisions log
| Area | Decision |
|---|---|
| Cloud region | eu-frankfurt-1 |
| Nodes | 2× VM.Standard.A1.Flex, 2 OCPU / 12 GB / 90 GB boot each |
| Node IPs (static) | server: 10.0.1.10 (pub 92.5.175.220), agent: 10.0.1.11 (pub 130.61.30.156) |
| Topology | 1× k3s server + 1× k3s agent. No etcd HA (2 nodes). Pods run on both (server not tainted) |
| k3s version | v1.33, embedded etcd via `--cluster-init` |
| CNI | **k3s default** (flannel + kube-proxy). **Cilium dropped** 2026-10-01 after pod-to-API `No route to host` saga |
| Load balancer | **OCI Flexible LB 10 Mbps — LIVE** (public IP `92.5.123.40`). All DNS → LB |
| Terraform state | Cloudflare R2 bucket `tfstate-k3s` (S3 backend) |
| DNS | Cloudflare; wildcard `*.raoshahzaib.site` A → LB IP (no DNS churn on rebuild) |
| Ingress | Traefik (bundled with k3s) |
| TLS | cert-manager, DNS-01 via Cloudflare, per-app certs, auto-renew |
| GitOps | ArgoCD v3.5.3 app-of-apps; auto-sync + prune + selfHeal |
| Secrets | **ESO + OCI Vault**; Terraform-managed, ESO syncs to K8s. R2 creds **rotated 2026-10-03** |
| SSO | **Keycloak 26.0.8** (Supabase Postgres). Grafana: Keycloak + Google OAuth ✅. ArgoCD OIDC: paused |
| Database | **Contract:** apps consume `DATABASE_URL` — swappable. **Default:** Supabase Postgres |
| Monitoring | kube-prometheus-stack (Prometheus + Grafana + Alertmanager). Custom SRE dashboard as Grafana home |
| Homepage | gethomepage.dev v2.4.0 — cluster landing page with live widgets |
| Backups | Velero → R2, daily, TTL 30d. **Restore tested 2026-10-03** ✅ (namespace delete → restore → running) |
| etcd snapshots | 6-hourly, 72 retained, shipped to R2 |
| Image registry | **Docker Hub**, public repos |
| CI | GitHub Actions per app repo: build → push Docker Hub → ArgoCD sync |
| Storage | **No Longhorn** — removed from scope 2026-09-30. Apps use external DB (Supabase) |
| SSH | Open via admin_cidr (`0.0.0.0/0` for now) |
| Cost guard | OCI Budget alert at $0 |

## Out of scope (decided)
- **Longhorn** — removed 2026-09-30
- **Page-Manager-Pro** — removed from platform scope
- **TaskFlow / GhostInbox** — learning projects, not deployed here
- **Cilium/eBPF** — dropped for k3s default networking
- **Falco** — not yet deployed
- **ArgoCD OIDC** — paused until Grafana SSO verified (then resume)

## Milestones completed
| Date | Milestone |
|------|-----------|
| 2026-09-28 | Infra + ArgoCD + ESO + Vault migration complete |
| 2026-09-30 | Velero backups live; monitoring (Prometheus/Grafana) live |
| 2026-10-01 | DR tested end-to-end (full VM rebuild) |
| 2026-10-02 | Fresh cluster on static IPs; OCI LB live; CreatorWatch deployed |
| 2026-10-03 | Keycloak SSO live; Grafana Keycloak+Google OAuth; Velero restore tested; R2 creds rotated |
| 2026-10-05 | Homepage cluster dashboard live |

## Disaster recovery
**Tested 2026-10-01.** Trigger: VM deleted / region issue / manual.
1. `infra.yml`: terraform apply → new VMs (static private IPs)
2. `ansible.yml`: k3s rebuild → ArgoCD install
3. ESO auto-syncs secrets from OCI Vault
4. ArgoCD syncs all apps from git
5. cert-manager reissues certs (DNS-01, automatic)
6. Velero restore if data loss (tested ✅)

**RTO: ~20–30 min. RPO: ≤24h.** Known SPOF: single k3s server (accepted, stated openly).

## GitHub secrets
`OCI_TENANCY_OCID, OCI_USER_OCID, OCI_FINGERPRINT, OCI_PRIVATE_KEY,`
`TF_VAR_*, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ACCOUNT_ID,`
`CLOUDFLARE_API_TOKEN, K3S_CLUSTER_TOKEN`
