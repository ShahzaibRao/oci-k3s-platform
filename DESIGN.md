# Platform Design Document — OCI k3s Production Platform

| Field | Value |
|---|---|
| Version | 2.0 (LIVE) |
| Date | 2026-10-05 |
| Status | ✅ Production — live since 2026-10-02, serving real traffic |
| Author | Rao Shahzaib |
| Companion | `ARCHITECTURE.md` (decision log) |

---

## 0. Implementation Status (2026-10-05)

This design was implemented with the following **deviations** (documented in ARCHITECTURE.md):

| Planned | Actual | Reason |
|---------|--------|--------|
| Cilium eBPF CNI | k3s default (flannel + kube-proxy) | Pod-to-API `No route to host` saga 2026-10-01 |
| Longhorn storage | Removed (no PV storage) | Out of scope 2026-09-30; apps use external DB |
| Gateway API | Standard Ingress | Simpler; Traefik Ingress works fine |
| Page-Manager-Pro | Not deployed | Out of scope; CreatorWatch only |
| LB deferred | **LB live** since 2026-10-02 | App go-live happened |
| Falco | Not yet deployed | Deferred |
| Hubble | Not available | No Cilium |

**New additions not in original design:**
- Keycloak 26.0.8 SSO (Grafana Keycloak+Google OAuth)
- Homepage cluster dashboard (gethomepage.dev)
- Static private IPs (10.0.1.10, 10.0.1.11)

---

## 1. Purpose & Scope

### 1.1 Purpose
Design a production-grade Kubernetes platform on OCI Always Free that hosts
real user-facing applications with GitOps deployments, end-to-end security,
observability, and a tested disaster-recovery path — while serving as a
public portfolio of DevOps/DevSecOps capability.

### 1.2 In scope
- Cloud infrastructure (network, compute, DNS, object storage) via Terraform
- Kubernetes platform (k3s, Cilium eBPF, storage, ingress, TLS)
- GitOps deployment system (ArgoCD, app-of-apps)
- CI/CD pipelines with security gates (app repos + infra repo)
- Secrets management + rotation, backup/restore, monitoring/alerting
- Two initial workloads: Page-Manager-Pro, CreatorWatch

### 1.3 Out of scope (v1)
- Multi-region / multi-cloud
- Control-plane HA (3+ servers) — path preserved, not built
- Service mesh (Istio/Linkerd)
- Paid SaaS of any kind

---

## 2. Goals & Non-Goals

**Goals**
1. `git push` → production in ~5 minutes, fully automated
2. Zero-touch rebuild: any VM loss recoverable in ≤30 min (RTO)
3. Security at every layer, demonstrable (badges, dashboards, blog series)
4. $0/month operating cost
5. Every component replaceable behind a stable contract (DB, storage, ingress)

**Non-goals**
1. 99.99% uptime — single control plane is an accepted SPOF
2. Autoscaling beyond 2 fixed nodes
3. Supporting workloads the platform wasn't asked for (GPU, Windows nodes)

---

## 3. Constraints & Assumptions

| # | Constraint | Impact |
|---|---|---|
| C1 | OCI Always Free: 4 OCPU / 24 GB RAM / 200 GB boot, single tenancy | 2 nodes max at 2/12/90 each; no HA control plane |
| C2 | eu-frankfurt-1 ARM capacity is unreliable | Terraform retries + documented x86 fallback |
| C3 | All tooling must be free/OSS | No paid SaaS; SonarCloud only because repos are public |
| C4 | Single operator (one person) | Mono-repo; break-glass procedures over on-call rotations |
| C5 | Supabase free: 500 MB DB, projects pause after 7d inactivity | Apps must tolerate DB cold-starts; not for >500 MB datasets |

**Assumptions:** A1: Operator holds OCI tenancy admin. A2: `raoshahzaib.site`
DNS is on Cloudflare. A3: GitHub Actions runners (free tier) are sufficient
for build/test workloads.

---

## 4. Architecture Overview

```
                        ┌─────────────────────────────────────────┐
                        │              GitHub (mono-repo)          │
                        │  infra/  ansible/  gitops/  workflows   │
                        └──────┬──────────────────────┬───────────┘
                               │ infra.yml            │ app pipelines
                               ▼                      ▼
┌──────────────┐      ┌──────────────────┐   ┌────────────────────┐
│ Cloudflare   │      │  OCI Frankfurt   │   │  Docker Hub + SonarCloud* │
│ DNS + R2     │◄────►│  2× A1.Flex VMs  │   │  Trivy, gitleaks   │
│ (state,      │      │  k3s + Cilium    │   │  Checkov           │
│  backups)    │      │  ArgoCD GitOps   │   │                    │
└──────────────┘      └────────┬─────────┘   └────────────────────┘
                               │ Gateway API + TLS
                               ▼
                      ┌─────────────────┐     ┌────────────┐
                      │ page-manager-pro│     │ Supabase   │
                      │ creatorwatch    │────►│ Postgres   │
                      │ (namespaces)    │     │ (external) │
                      └─────────────────┘     └────────────┘
```

---

## 5. Infrastructure Design

### 5.1 Network
- **VCN** `10.0.0.0/16` (single; production would segment, free tier keeps it simple)
- **Public subnet** `10.0.1.0/24` — both nodes (no private subnet: no NAT gateway in free tier; documented tradeoff)
- **Internet Gateway** + public route table (`0.0.0.0/0` → IGW)
- **Security list** (stateful):
  - Egress: all → `0.0.0.0/0`
  - Ingress: all protocols ← `10.0.0.0/16` (node-to-node: flannel/VXLAN not needed post-Cilium, but kubelet 10250, etcd 2379/2380, hubble, health checks)
  - Ingress: TCP 22, 6443 ← `admin_cidr` only
  - Ingress: TCP 80, 443 ← `0.0.0.0/0` (Traefik)
  - Ingress: ICMP ← `0.0.0.0/0`

### 5.2 Compute
- 2× `VM.Standard.A1.Flex`, shape config 2 OCPU / 12 GB, boot 90 GB each (180/200 GB)
- AD spread: server → AD-1, agent → AD-2
- Image: Canonical Ubuntu 22.04 ARM via data source (latest, no hardcoded OCID)
- `create_before_destroy` lifecycle on instances (node replacement without downtime where possible)
- SSH key injected via instance metadata (bootstrap only)

### 5.3 Load balancer (Always Free) — DEFERRED to app go-live
- **Decision 2026-09-28:** LB is NOT provisioned with initial infra. No workloads exist yet, so it would sit idle.
- When the first app goes live: **1× OCI Flexible Load Balancer, shape fixed at 10 Mbps** (the only free shape; exactly one instance — a second LB or more bandwidth = charges)
- Terraform-managed; backends = both nodes, ports 80/443; health check against Traefik `/ping`
- Single public entrypoint; Traefik DaemonSet stays behind it
- Module code already written and reviewed; restore via `git revert` of the deferral commit

### 5.4 DNS (Cloudflare provider in Terraform) — DEFERRED to app go-live
- Deferred together with the LB (no traffic to route yet)
- When live: wildcard `*.raoshahzaib.site` A record → **load balancer public IP** (not node IPs); apex record → load balancer public IP
- Managed in Terraform so rebuild re-points DNS automatically

### 5.5 Object storage (R2, manual one-time)
| Bucket | Purpose | Versioning |
|---|---|---|
| `tfstate-k3s` | Terraform state | ON |
| `velero-backups` | Velero PV backups + etcd snapshots | ON |

### 5.6 Terraform workflow
- **Backend:** S3-compatible (R2), native lockfile (`use_lockfile`), partial config via CI flags
- **Auth:** `OCI_*` env vars from GitHub Secrets (no config file in CI)
- **Plan on PR** (read-only, posts diff as comment) → **Apply on merge to main** (infra.yml)
- **Drift check:** every 15 min `terraform plan -detailed-exitcode` (drift.yml).
  exit 2 → if any `oci_core_instance` is planned for **creation** (VM gone):
  targeted auto-`apply` recreates it, then the Ansible portion of infra.yml
  rejoins the node. Any other drift → GitHub issue alert, no auto-apply.

### 5.7 Automatic disaster recovery (drift-triggered)
- Missing/deleted VMs are recreated **automatically** by the drift workflow above
  (machines self-heal; config changes still need human approval — never auto-applied)
- Full-cluster loss (both VMs): same path recreates both; ArgoCD + Velero restore
  follow per §12.3 (Velero restore step stays manual-gated in v1)

---

## 6. Kubernetes Platform Design

### 6.1 k3s
- Version pinned **v1.33** (Ansible variable)
- **Embedded etcd** via `--cluster-init` (single node today; add servers later for HA, no rebuild)
- Server flags: `--flannel-backend=none --disable-network-policy --disable-kube-proxy --cluster-init --etcd-snapshot-schedule-cron "0 */6 * * *" --etcd-snapshot-retention 72` (retention = count: 72 snapshots × 6h ≈ 18 days)
- etcd snapshots shipped to R2 (cron on server)
- Agent joins via node-token (Ansible-fetched; break-glass join playbook for future nodes)

### 6.2 Networking — Cilium (eBPF)
- Installed by Ansible (CNI must precede workloads; not via ArgoCD)
- `kubeProxyReplacement=true` (pure eBPF, no iptables kube-proxy)
- Hubble enabled (flow observability → Grafana)
- Default-deny `CiliumNetworkPolicy` per namespace; explicit allow rules per app

### 6.3 Storage — Longhorn (primary)
- **Longhorn** installed via ArgoCD (Phase 1); **default StorageClass**, replica count 2 across both nodes
- Node loss no longer loses data → **nodeAffinity pinning rule retired** (only applies if local-path is ever used directly)
- **Recurring backups to R2** (S3-compatible backup target), daily; restore via Longhorn UI/CRD
- `local-path` kept as fallback StorageClass only
- Disk math (tight but fits): ~110 GB replicated data + ~40 GB OS/images ≈ 150/180 GB — media volume capped at 30 GB

### 6.4 Ingress & TLS
- **Traefik** DaemonSet, `hostPort` 80/443 on both nodes; OCI Flexible LB (10 Mbps) added in front at app go-live (§5.3)
- **Gateway API** (`Gateway` + `HTTPRoute`) — no legacy Ingress
- **cert-manager** + Cloudflare DNS-01 → wildcard `*.raoshahzaib.site`, auto-renew

### 6.5 Multi-tenancy
- One namespace per app + `infra-*` namespaces for platform components
- Each app namespace: `ResourceQuota`, `LimitRange`, default-deny network policy
- Pod Security Standards: `restricted` enforced cluster-wide

---

## 7. GitOps & Deployment Design

### 7.1 Layout
```
gitops/
├── bootstrap/root.yaml      # App-of-apps. ONLY object Ansible applies
└── apps/
    ├── infra/               # one dir per component, each with enabled: flag
    └── workloads/<app>/     # namespace, quota, netpol, HTTPRoute, ExternalSecrets
```

### 7.2 ArgoCD
- Installed by Ansible (Helm chart pinned), root app applied once
- All apps: automated sync + prune + selfHeal
- RBAC: admin SSO deferred (v1: local admin, password in GitHub Secret, rotated)

### 7.3 Application onboarding contract (new app checklist)
1. Namespace + quota + limitrange + default-deny netpol
2. `DATABASE_URL` ExternalSecret (Supabase or CNPG — app doesn't care)
3. PVCs (if any) with nodeAffinity
4. `HTTPRoute` for public exposure
5. PDB if >1 replica
6. Image Updater annotation for auto-deploys

### 7.4 Database abstraction
- **Contract:** app reads `DATABASE_URL` from env (ESO-synced Secret). Nothing else.
- **Default implementation:** Supabase Postgres
- **Supabase risk defense (free tier has no backups; 90d paused → deleted):**
  keep-alive cron (GitHub Actions pings `/auth/v1/health` every 2–3 days) +
  daily `pg_dump` → R2 (CronJob) → restore to new Supabase project or CNPG
- **Optional:** CNPG operator (feature-flagged, `enabled: false`) → flip flag, point secret at in-cluster service

---

## 8. CI/CD Design

### 8.1 Infra pipeline (`infra.yml`, infra repo)
```
PR → terraform fmt/validate → Checkov → plan (comment on PR)
merge → apply → terraform output → generate Ansible inventory
      → ansible-playbook site.yml (common → k3s_server → cilium → k3s_agent → argocd)
```

### 8.2 App pipeline (each app repo)
```
push/PR → gitleaks → build → Trivy image scan (fail on HIGH/CRITICAL)
        → SonarCloud SAST (quality gate) → push docker.io (public)
        → ArgoCD Image Updater bumps tag → ArgoCD syncs → live
```

### 8.3 Security gates summary
| Gate | Where | Fail behavior |
|---|---|---|
| gitleaks | every PR | block merge |
| Checkov | infra PR | block merge |
| Trivy | app build | block push |
| SonarCloud | app PR | block merge (quality gate) |
| PSS restricted | admission | block deploy |
| Cilium netpol | runtime | block traffic |

---

## 9. Security Design

### 9.1 Threat model (top risks)
| Threat | Mitigation |
|---|---|
| Secret leaked in git | gitleaks (local + CI), ESO + OCI Vault (no secrets in git) |
| Compromised container escapes | non-root, read-only FS where possible, PSS restricted, Falco alerts |
| Lateral movement pod→pod | default-deny Cilium policies per namespace |
| Stale/vulnerable image | Trivy gate, Image Updater keeps tags fresh |
| Lost credentials / rogue admin | break-glass runbook, admin_cidr restriction, audit via git history |
| Data loss | Velero daily, etcd snapshots 6-hourly, Supabase backups |

### 9.2 Secrets management
- **At rest in git:** ExternalSecret manifests (reference only); plaintext never committed — values live in OCI Vault
- **Controller key:** backed up to R2 (scheduled CronJob); restored before app sync in DR
- **Rotation:** 90-day runbook — new key → `kubeseal --re-encrypt` all → backup new key → keep old 1 cycle → rolling restart → verify
- **CI secrets:** GitHub Secrets; OCI private key never leaves CI

### 9.3 Supply chain
- Images: pinned digests in GitOps (Image Updater moves tags, digests recorded)
- Base images: minimal/distroless, rebuilt regularly
- No `:latest` in production manifests

---

## 10. Data Design

| Data | Lives in | Backup | RPO |
|---|---|---|---|
| App relational data | Supabase Postgres | Supabase built-in + **own pg_dump daily → R2** (free tier has no backups) | 24h |
| CreatorWatch media | PVC (Longhorn, replica 2) | Longhorn recurring backup → R2, daily, TTL 30d | 24h |
| PMP uploads staging | PVC (Longhorn, replica 2) | Longhorn recurring backup → R2, daily, TTL 30d | 24h |
| Cluster state | etcd (embedded) | snapshots 6-hourly → R2 | 6h |
| Prometheus metrics | PVC 20 GB | not backed up (recreatable) | n/a |

---

## 11. Observability Design

- **Metrics:** kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
- **Network flows:** Hubble → Grafana
- **Runtime security:** Falco → Alertmanager → (notification channel TBD)
- **Logs:** v1 = `kubectl` + Grafana Explore via kubelet; Loki optional Phase 4
- **Dashboards (portfolio):** cluster overview, per-app golden signals, Hubble service map, Falco alerts
- **Alerting:** Alertmanager; critical alerts = node down, cert expiry <14d, Velero backup failed, disk >80%

---

## 12. Disaster Recovery Design

### 12.1 Objectives
- **RTO:** ≤30 min (full VM loss → apps live)
- **RPO:** ≤24h PVs, ≤6h cluster state, DB per Supabase

### 12.2 Scenarios
| Scenario | Path | Time |
|---|---|---|
| App pod crash | K8s self-heal | seconds |
| Node (agent) loss | Longhorn replica promotes on surviving node; pods reschedule, data intact | minutes |
| Node (server) loss | Full rebuild via drift workflow (§5.6) | ~25 min |
| Cluster state corrupt | etcd snapshot restore on server | ~5 min |
| Data corrupt | Velero restore (apps scaled to 0 first) | ~15 min |
| State file lost | R2 versioning restore → `terraform refresh` | ~10 min |
| Region down | Out of scope v1 (documented) | — |

### 12.3 Rebuild order (full)
1. `infra.yml` manual dispatch → Terraform apply → new VMs
2. Inventory → `ansible-playbook site.yml` (k3s → Cilium → ArgoCD → root app)
3. ESO pulls secrets from OCI Vault automatically (no key restore needed)
4. ArgoCD sync **infra only**
5. Velero restore (data back)
6. ArgoCD sync **workloads** (apps start on restored data)
7. DNS: no change needed — records point at the LB (stable IP); only LB backends update to new node IPs
8. Verify: health checks, data spot-checks, TLS

Full step-by-step with exact commands → `RUNBOOK.md` (written at implementation).

---

## 13. Operations Design

- **Drift detection:** daily `terraform plan`; alert on exit 2; fix in code, never console
- **Node recycling:** monthly (or on CVE): cordon → drain → taint VM → Terraform replaces → Ansible rejoins. No snowflake servers
- **k3s upgrades** (manual trigger, coded procedure): etcd snapshot first →
  bump version var in PR → review → manual dispatch `upgrade-k3s.yml` →
  server: drain → new binary → restart → verify → uncordon → agent: same →
  smoke tests. Patch/minor only; upgrades never automatic.
- **Maintenance windows:** announced; PDBs protect infra during drains
- **Access control:** SSH via admin_cidr only; 6443 same; ArgoCD admin via port-forward/SSO later
- **Change management:** everything via PR; infra PRs require plan comment; no direct pushes to main

---

## 14. Cost Design

| Item | Cost |
|---|---|
| OCI (4 OCPU/24 GB/200 GB) | $0 (Always Free) |
| OCI Flexible LB (10 Mbps, exactly 1) | $0 (Always Free) |
| R2 (state + backups, <10 GB) | $0 (free tier) |
| Cloudflare DNS | $0 |
| GHCR / GitHub Actions | $0 (free tier) |
| Supabase (2 projects) | $0 (free tier) |
| SonarCloud (public repos) | $0 |
| **Total** | **$0/month** |

**Guardrail:** OCI Budget alert at $0 actual/forecast spend → email.

---

## 15. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| ARM capacity unavailable (Frankfurt) | Med | Blocks provisioning | Retry logic; documented x86 fallback (weaker) |
| Single server node dies | Low-Med | Full rebuild | RTO 30 min; etcd snapshots |
| Supabase free pause (7d idle) / delete (90d paused) | Med | DB cold start or data loss | Keep-alive cron + own pg_dump daily → R2; restore plan documented |
| Second LB or >10 Mbps shape | Low | Unexpected charges | Terraform pins exactly 1 LB at 10 Mbps; budget alert |
| R2 free tier exceeded | Low | Backup failures | Alert on bucket size; retention policy |
| Operator error (bad apply) | Med | Outage | PR plan reviews; etcd snapshots; Velero |
| OCI Vault unavailable | Low | Secrets not syncable | Vault is regional HA; ESO retries with backoff |
| Scope creep (too many components) | Med | Unmaintainable | Feature flags; phased rollout; this doc |

---

## 16. Rollout Phases

- **Phase 1:** infra + k3s (Cilium/etcd) + ArgoCD + ESO + OCI Vault + Velero. No apps
- **Phase 2:** Traefik/Gateway API + cert-manager + page-manager-pro live
- **Phase 3:** creatorwatch live (Dockerfile + media PVC)
- **Phase 4:** monitoring + Falco + DR drill (delete a VM, measure RTO). Loki/CNPG if needed

## 17. Open Decisions
- Subdomain names per app
- admin_cidr lockdown to personal IP before first apply
- SAST: SonarCloud (recommended, free for public) vs SonarQube self-hosted vs Semgrep — **pending your pick**
- Confirm: k3s v1.33, ArgoCD Image Updater (assistant-picked, awaiting confirmation)
- Falco → notification channel (Telegram/Email)
- Notion Chapter 03: "Kubernetes Security Best Practices"

*§4, §8: SonarCloud shown as recommended default until you pick.*

## Appendix A — Resource budget (~9.5 GB / 24 GB)
k3s 1.5 · Cilium/Hubble 1.0 · ArgoCD(+updater) 1.5 · Traefik/cert-manager 0.7 · ESO 0.10.5 ·
monitoring 2.5 · Velero/Falco 0.6 · apps 1.5. Disk: ~72/90 GB per node.

## Appendix B — Glossary
RTO/RPO, GitOps, eBPF, Gateway API, ESO, PDB, PSP→PSS, DR, SPOF.
