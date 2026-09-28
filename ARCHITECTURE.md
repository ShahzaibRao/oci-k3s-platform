# OCI k3s Production Platform — Architecture (LOCKED)

> Status: PLANNING ONLY. Nothing has been applied. This document is the
> single source of truth for implementation.
> Last reviewed: 2026-09-28 (v6: OCI free LB in front of Traefik,
> Longhorn primary storage with R2 backups, Supabase keep-alive + pg_dump defense).
> 2026-09-28 implementation decision: LB + Cloudflare DNS **deferred to app
> go-live** — initial infra is network + compute (VMs) only. LB module code
> reviewed and preserved in git history.

## Goal
Production-style Kubernetes platform on OCI Always Free, hosting real apps
(Page-Manager-Pro, CreatorWatch) for real users. Recruiter-visible: GitOps,
Gateway API, eBPF/Cilium, TLS, monitoring, backups, disaster recovery,
DevSecOps at every layer.

## Non-negotiables
- 100% free-tier only: OCI Always Free (4 OCPU / 24 GB RAM / 200 GB boot),
  Cloudflare R2 free allowance, all CNCF/OSS components (no paid SaaS).
- SSH kept open for now via admin_cidr (hardening deferred, one variable away).
- Everything declarative in git. Rebuild from zero in ~20–30 min.

## Repository layout (mono-repo)
```
.
├── infra/          # Terraform: network + compute modules, Cloudflare DNS
├── ansible/        # Roles: common, k3s_server, cilium, k3s_agent, argocd
├── gitops/
│   ├── bootstrap/  # root app (app-of-apps) — only thing Ansible applies
│   └── apps/
│       ├── infra/      # sealed-secrets, cilium-policies, cert-manager,
│       │               # traefik, velero, kube-prometheus-stack,
│       │               # falco, cnpg (feature-flagged, disabled by default)
│       └── workloads/  # page-manager-pro, creatorwatch (namespace per app)
└── .github/workflows/
    ├── infra.yml   # terraform apply -> inventory -> ansible site.yml
    └── add-node.yml# break-glass: temp-open 22 -> join_node.yml -> close 22
```

## Decisions log
| Area | Decision |
|---|---|
| Cloud region | eu-frankfurt-1 (ARM capacity retries planned; x86 fallback documented) |
| Nodes | 2× VM.Standard.A1.Flex, 2 OCPU / 12 GB / 90 GB boot each (180/200 GB) |
| Topology | 1× k3s server (AD-1) + 1× k3s agent (AD-2). No etcd HA (2 nodes) |
| k3s version | Pinned **v1.33** in Ansible (supported through ~mid 2027) |
| k3s datastore | Embedded **etcd** via `--cluster-init` (not SQLite) — enables etcd snapshots to R2 + future HA (add servers later, no rebuild) |
| CNI | **Cilium (eBPF)** — kube-proxy replacement, Hubble enabled. k3s flags: `--flannel-backend=none --disable-network-policy --disable-kube-proxy` |
| Terraform state | Cloudflare R2 bucket `tfstate-k3s` (S3 backend, native lockfile) |
| DNS | Cloudflare provider in Terraform; wildcard `*.raoshahzaib.site` A record → **load balancer IP** (stable; no DNS churn on VM rebuild). Per-app names decided later |
| Ingress | OCI LB (10 Mbps, free) → Traefik DaemonSet (hostPort 80/443, both nodes) + **Gateway API** (HTTPRoute) |
| TLS | cert-manager, DNS-01 via Cloudflare, wildcard cert, auto-renew |
| GitOps | ArgoCD app-of-apps; auto-sync + prune + selfHeal on all apps |
| Image updates | **ArgoCD Image Updater** watches GHCR (fits frequent vibe-code updates) |
| Secrets | Sealed Secrets; **controller private key backed up to R2** (scheduled) and restored on rebuild — else old secrets undecryptable. **90-day key rotation runbook** (re-encrypt all, backup new key, keep old 1 cycle) |
| Database | **Contract:** apps only consume a `DATABASE_URL` secret — implementation is swappable. **Default:** Supabase Postgres (free tier). **Risk defense:** keep-alive cron (pause rokne ke liye) + daily `pg_dump` → R2 (90d paused → delete hota hai; free tier ka apna backup nahi). **Optional:** CNPG operator as feature-flagged infra app (`enabled: false` default) |
| Multi-tenancy | Namespace per app + ResourceQuota + LimitRange + Cilium default-deny NetworkPolicy per namespace |
| Resilience | PodDisruptionBudgets on infra components; feature flags (`enabled:`) on every infra app in app-of-apps |
| Cluster/PV backup | Velero → R2 `velero-backups`, daily schedule, TTL 30d (deployed Phase 1, before any app goes live) |
| Image registry | **Docker Hub**, repos **public** (no imagePullSecrets; anonymous pull limit 100/6h per IP — fine for 2 nodes) |
| CI | GitHub Actions per app repo: build → Trivy scan → SonarCloud* → push Docker Hub → Image Updater → ArgoCD sync (*pending final Sonar pick) |
| Monitoring | kube-prometheus-stack (Prometheus PVC 20GB); requests/limits on everything; Loki optional Phase 4 |
| Storage | **Longhorn** (default StorageClass, replica 2 across nodes) + recurring backups → R2. local-path fallback only. Node-pinning rule retired |
| SSH | Open via admin_cidr for now |
| Cost guard | OCI Budget alert at $0 (free, production habit) |

## Resource budget (of 24 GB RAM)
| Component | ~RAM |
|---|---|
| k3s server+agent | 1.5 GB |
| Cilium + Hubble | 1.0 GB |
| ArgoCD (+ Image Updater) | 1.5 GB |
| Traefik + cert-manager + sealed-secrets | 0.7 GB |
| kube-prometheus-stack | 2.5 GB |
| Velero + Falco | 0.6 GB |
| page-manager-pro (2 pods) | 1.0 GB |
| creatorwatch | 0.5 GB |
| Longhorn (storage) | 1.0 GB |
| **Total** | **~10.5 GB / 24 GB** ✅ headroom for growth |

Disk (90 GB boot/node): OS ~10 + images ~10 + Longhorn replicas share (~55/node avg) ≈ 75 GB ✅ (media capped at 30 GB)

## Security — DevSecOps at every layer
Shift-left, all free/OSS, all visible (badges in README).
Security workflows live in each **app repo** (not the infra repo):

| Layer | Controls |
|---|---|
| Git | `.gitignore` from day 1; pre-commit + gitleaks hooks; gitleaks-action on every PR; branch protection (no direct push to main, PR reviews required) |
| IaC | No hardcoded secrets (env/GitHub secrets only); R2 remote state + lockfile; **Checkov** scan in `infra.yml` (fail on HIGH) |
| CI/CD | **Trivy** image scan on every build (fail on HIGH/CRITICAL before push); **SonarCloud** SAST + quality gate (free: both repos public) |
| Containers | Non-root USER; distroless/minimal + multi-stage builds |
| Cluster | Sealed Secrets (+ key backup); PSS `restricted`; Cilium default-deny NetworkPolicies |
| Runtime | **Falco** (eBPF threat detection) → alerts to Grafana |
| TLS | cert-manager, DNS-01, wildcard cert, auto-renew |

Portfolio story: "Implemented my own DevSecOps guide (blog series) on this
platform" — badges + Grafana/Hubble/Falco screenshots as proof.

## Network (Terraform `modules/network`)
- VCN 10.0.0.0/16, public subnet 10.0.1.0/24, IGW + public route table
- Security list: egress all; ingress all from VCN CIDR (node-to-node);
  22 + 6443 from admin_cidr only; 80/443 world; ICMP world

## CI/CD flow (per app repo)
```
git push
  -> build image -> Trivy scan (fail HIGH/CRITICAL) -> SonarCloud SAST
  -> push docker.io/<user>/<app>:<sha>
  -> ArgoCD Image Updater bumps tag in gitops repo
  -> ArgoCD syncs (auto, prune, selfHeal)
  -> Traefik (Gateway API HTTPRoute) -> TLS -> live
```

## Disaster recovery
Trigger: VM deleted / region issue / manual.
1. `infra.yml` (manual dispatch): terraform apply → new VMs
2. Same workflow: generate inventory → `ansible-playbook site.yml`
   (k3s rebuild → Cilium → ArgoCD install → root app)
3. Restore **sealed-secrets private key** from R2 (before app sync)
4. ArgoCD syncs infra + workloads from git
5. cert-manager reissues wildcard cert (DNS-01, automatic)
6. Terraform updates LB backends to new node IPs (DNS unchanged — points at LB)
7. Velero restore (only if data loss)
8. etcd snapshot restore (only if cluster state itself is corrupt — snapshots ship to R2 on schedule)

**RTO: ~20–30 min. RPO: ≤24h (daily Velero for PVs; DB covered by Supabase built-in backups).**
Known SPOF: single k3s server. Accepted for free tier; stated openly.

## Buckets to create (manual, one-time)
- `tfstate-k3s` — Terraform state
- `velero-backups` — Velero backups + sealed-secrets key backup
- R2 S3 API token (read/write) → GitHub secret

## GitHub secrets needed (at build time)
`OCI_TENANCY_OCID, OCI_USER_OCID, OCI_FINGERPRINT, OCI_PRIVATE_KEY,`
`TF_VAR_tenancy_ocid, TF_VAR_compartment_id, TF_VAR_ssh_public_key,`
`TF_VAR_admin_cidr, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ACCOUNT_ID,`
`CLOUDFLARE_API_TOKEN`

## App pipelines
- **page-manager-pro**: 2 images (nextjs frontend, express backend; Dockerfiles exist).
  `FB_SYSTEM_USER_TOKEN` + Supabase connection string via SealedSecret.
  Uploads staging on small PVC (Longhorn, replica 2).
  Pipeline: build → Trivy → SonarCloud* → Docker Hub → Image Updater → ArgoCD.
- **creatorwatch**: 1 image (Flask + yt-dlp; Dockerfile to be written: python-slim,
  non-root). Media downloads on dedicated PVC (~30GB, Longhorn replica 2).
  Supabase connection string via SealedSecret. Same pipeline.
  (* SonarCloud recommended; final pick pending)

## Phases
- **Phase 1:** infra + k3s (Cilium) + ArgoCD + sealed-secrets (+ key backup) + Velero. Platform up, no apps
- **Phase 2:** traefik/Gateway API + cert-manager + page-manager-pro live (first real user traffic)
- **Phase 3:** creatorwatch live (Dockerfile + pipeline + media PVC)
- **Phase 4:** monitoring + Falco + DR drill (delete VM, rebuild, verify RTO). Loki if needed

## Open items (decided later)
- Subdomain names per app
- admin_cidr lockdown to personal IP before first apply
- SAST: SonarCloud (recommended, free for public) vs SonarQube self-hosted vs Semgrep — **tumhara faisla pending**
- Confirm: k3s v1.33, ArgoCD Image Updater (both assistant-picked, not yet confirmed by you)
- Chapter 03 for Notion: "Kubernetes Security Best Practices"
