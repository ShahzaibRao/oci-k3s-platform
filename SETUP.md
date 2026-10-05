# SETUP.md — Apna Cluster Banao

Ye repo ek **template** hai. Apna Kubernetes platform banane ke liye in steps ko follow karo.

> **Note:** Ye setup production-tested hai — 2026-10-01 ko full DR rebuild test pass hua.

## Prerequisites

- Oracle Cloud account (free tier)
- Cloudflare account (R2 + DNS)
- GitHub account
- Domain name (Cloudflare mein managed)
- Supabase account (Postgres for Keycloak — free tier)

## Step 1: Values Change Karo

Apne domain/email/R2 ke hisaab se ye files edit karo:

### 1. `apps/cloudflare/cluster-issuer.yaml`
```yaml
email: contact@raoshahzaib.site   # ← apna email dalo
```

### 2. Domain replace karo
```bash
# VS Code mein Ctrl+Shift+F → `raoshahzaib.site` → apna domain
# Files: apps/*/ingress.yaml, apps/*/certificate.yaml
```

### 3. `infra/` Terraform variables
```bash
# infra/variables.tf dekho — har secret ke liye TF_VAR_* chahiye
```

**Tip:** VS Code mein `Ctrl+Shift+F` → `raoshahzaib.site` search karo → sab ek saath replace.

## Step 2: GitHub Secrets

Repo Settings → Secrets → Actions mein ye add karo:

| Secret | Kahan se milega |
|--------|-----------------|
| `OCI_TENANCY_OCID`, `OCI_USER_OCID`, `OCI_FINGERPRINT`, `OCI_PRIVATE_KEY` | Oracle Cloud → API Keys |
| `TF_VAR_*` | Har Terraform variable ke liye (variables.tf dekho) |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ACCOUNT_ID` | Cloudflare R2 → API Tokens |
| `CLOUDFLARE_API_TOKEN` | Cloudflare → API Tokens (DNS edit) |
| `K3S_CLUSTER_TOKEN` | k3s install ke baad server se |

## Step 3: Order of Operations

```text
1. Terraform  → VMs + LB + OCI Vault
   (GitHub Actions: infra.yml)

2. Ansible    → k3s + ArgoCD install
   (GitHub Actions: ansible.yml)

3. ArgoCD     → baaki sab automatic sync hoga:
   Wave 0: cert-manager, external-secrets
   Wave 1: cloudflare, argocd
   Wave 2: monitoring, velero, keycloak, homepage, creatorwatch
```

## Step 4: DNS

Cloudflare mein A records banao → LB IP (`92.5.123.40` hamare case mein):

| Record | Target |
|--------|--------|
| `homepage` | LB IP |
| `grafana` | LB IP |
| `argocd` | LB IP |
| `auth` | LB IP |
| `cw` | LB IP |

## Step 5: Verify

```bash
# Sab apps Synced?
kubectl get applications -n argocd

# Pods running?
kubectl get pods -A | grep -v Running

# Certificates ready?
kubectl get certificates -A
# → sab Ready True hone chahiye

# Velero kaam kar raha?
kubectl get backupstoragelocation -n velero
# → Available hona chahiye
```

## Step 6: SSO Setup (Keycloak)

1. https://auth.YOUR-DOMAIN → admin console
2. Clients banao: `grafana`, `argocd`
3. Redirect URIs set karo:
   - Grafana: `https://grafana.YOUR-DOMAIN/login/generic_oauth`
   - ArgoCD: `https://argocd.YOUR-DOMAIN/auth/callback`
4. Client secrets → OCI Vault → `infra.yml` chalao
5. Grafana `values.yaml` mein OIDC config (dekho `apps/monitoring/values.yaml`)

## Step 7: Backup Test

```bash
# Manual backup
velero backup create test --include-namespaces creatorwatch

# Restore test (non-prod mein!)
kubectl delete namespace creatorwatch
velero restore create --from-backup test
```

## Nayi App Add Karna

`apps/` mein naya folder banao — har app ke paas apne resources:

```
apps/my-app/
  deployment.yaml
  service.yaml
  ingress.yaml
  certificate.yaml
  externalsecret.yaml   # agar secret chahiye
```

Phir `argocd/apps/applicationset.yaml` mein add karo:
```yaml
- name: my-app
  syncWave: "2"
```

## Rollback

Har change ek PR tha:
```bash
git log --oneline        # PRs dekho
git revert <commit-sha>  # Wapas jao
```
