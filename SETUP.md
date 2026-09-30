# SETUP.md — Apna Cluster Banao

Ye repo ek **template** hai. Apna Kubernetes platform banane ke liye in steps ko follow karo.

## Prerequisites

- Oracle Cloud account (free tier)
- Cloudflare account (R2 + DNS)
- GitHub account
- Domain name (Cloudflare mein managed)

## Step 1: Values Change Karo

Apne domain/email/R2 ke hisaab se ye **4 files** edit karo:

### 1. `apps/cloudflare/cluster-issuer.yaml`
```yaml
email: contact@raoshahzaib.site   # ← apna email dalo
```

### 2. `apps/argocd/ingress.yaml`
```yaml
- argocd.raoshahzaib.site          # ← argocd.APNA-DOMAIN
  secretName: wildcard-raoshahzaib-site-tls  # ← wildcard-APNA-DOMAIN-tls
```

### 3. `apps/argocd/certificate.yaml`
```yaml
name: wildcard-raoshahzaib-site    # ← wildcard-APNA-DOMAIN
secretName: wildcard-raoshahzaib-site-tls
dnsNames:
  - "*.raoshahzaib.site"           # ← *.APNA-DOMAIN
  - "raoshahzaib.site"             # ← APNA-DOMAIN
```

### 4. `argocd/apps/velero.yaml`
```yaml
- bucket: oci-k3s-velero           # ← apna R2 bucket naam
  s3Url: https://xxx.r2.cloudflarestorage.com  # ← apna R2 endpoint
```

**Tip:** VS Code mein `Ctrl+Shift+F` → `raoshahzaib.site` search karo → sab ek saath replace.

## Step 2: GitHub Secrets

Repo Settings → Secrets → Actions mein ye add karo:

| Secret | Kahan se milega |
|--------|-----------------|
| `TF_VAR_R2_ACCESS_KEY_ID` | Cloudflare R2 → API Tokens |
| `TF_VAR_R2_SECRET_ACCESS_KEY` | Cloudflare R2 → API Tokens |
| `OCI_*` | Oracle Cloud → API Keys |
| `ANSIBLE_SSH_PRIVATE_KEY` | Apni SSH key |
| `CLOUDFLARE_API_TOKEN` | Cloudflare → API Tokens (DNS edit) |

## Step 3: Order of Operations

```text
1. Terraform  → VMs + OCI Vault banao
   (GitHub Actions: infra.yml)

2. Ansible    → k3s + ArgoCD install karo
   (GitHub Actions: ansible.yml)

3. ArgoCD     → baaki sab automatic sync hoga:
   Wave 0: cert-manager, external-secrets
   Wave 1: cloudflare, velero-secrets, argocd
   Wave 2: velero
```

## Step 4: Verify

```bash
# Sab apps Synced?
kubectl get applications -n argocd

# Velero kaam kar raha?
kubectl get backupstoragelocation -n velero
# → Available hona chahiye

# Certificate mila?
kubectl get certificate -n argocd
# → Ready True hona chahiye
```

## Step 5: Backup Test

```bash
# Manual backup chalao
velero backup create test --include-namespaces default

# R2 mein check karo (Cloudflare dashboard)
```

## Rollback

Kuch ghalat hua? Har change ek PR tha:
```bash
git log --oneline        # PRs dekho
git revert <commit-sha>  # Wapas jao
```

## Nayi App Add Karna

`apps/README.md` dekho — template ready hai:
```
apps/my-app/
  externalsecret.yaml   # agar secret chahiye
  ingress.yaml          # agar domain chahiye
  certificate.yaml      # agar TLS chahiye
```

Phir `argocd/apps/applicationset.yaml` mein add karo.
