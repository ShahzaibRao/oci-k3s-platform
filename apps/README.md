# App Folder Template

Har nayi app ke liye `apps/<app-name>/` folder banao. Sirf wohi files rakho jo chahiye:

## Structure

```
apps/my-app/
  externalsecret.yaml   # Agar OCI Vault se secret chahiye
  ingress.yaml          # Agar domain/hostname chahiye
  certificate.yaml      # Agar TLS cert chahiye (cert-manager)
  deployment.yaml       # App ke apne manifests
  ...
```

## Examples

| App | Files | Kyun |
|-----|-------|------|
| `cloudflare` | `externalsecret.yaml` + `cluster-issuer.yaml` | API token + Let's Encrypt |
| `velero-secrets` | `externalsecret.yaml` | R2 credentials |
| `argocd` | `ingress.yaml` + `certificate.yaml` | Domain + TLS |

## ApplicationSet mein add karo

`argocd/apps/applicationset.yaml` mein:

```yaml
- name: my-app
  namespace: my-namespace  # optional, default = app name
  syncWave: "1"            # 0=foundation, 1=needs secrets, 2=needs other apps
```

## Sync Waves

- **0**: Operators, CRDs, ClusterSecretStore (foundation)
- **1**: ExternalSecrets, ClusterIssuers, Ingresses (need foundation)
- **2**: Apps needing secrets (e.g. Velero Helm chart)
