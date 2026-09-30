#!/bin/bash
# Applies template configuration to manifests.
# Usage: ./scripts/setup.sh
# Reads 'config' file (copy from config.example) and replaces
# ${DOMAIN}, ${DOMAIN_DASH}, ${EMAIL}, ${R2_BUCKET}, ${R2_ENDPOINT} placeholders.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f config ]]; then
  echo "ERROR: 'config' file not found."
  echo "  cp config.example config"
  echo "Then edit 'config' with your values and re-run."
  exit 1
fi

# Load config
set -a
source config
set +a

# Validate required vars
for var in DOMAIN EMAIL R2_BUCKET R2_ENDPOINT; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: $var is not set in 'config' file."
    exit 1
  fi
done

# DOMAIN_DASH: domain with dots replaced by dashes (for k8s resource names)
export DOMAIN_DASH="${DOMAIN//./-}"

echo "Applying configuration:"
echo "  DOMAIN      = $DOMAIN"
echo "  EMAIL       = $EMAIL"
echo "  R2_BUCKET   = $R2_BUCKET"
echo "  R2_ENDPOINT = $R2_ENDPOINT"
echo ""

# Files with placeholders
FILES=(
  "apps/argocd/ingress.yaml"
  "apps/argocd/certificate.yaml"
  "apps/cloudflare/cluster-issuer.yaml"
  "argocd/apps/velero.yaml"
)

python3 - "$DOMAIN" "$DOMAIN_DASH" "$EMAIL" "$R2_BUCKET" "$R2_ENDPOINT" "${FILES[@]}" << 'PYEOF'
import sys

domain, domain_dash, email, r2_bucket, r2_endpoint = sys.argv[1:6]
files = sys.argv[6:]

replacements = {
    '${DOMAIN}': domain,
    '${DOMAIN_DASH}': domain_dash,
    '${EMAIL}': email,
    '${R2_BUCKET}': r2_bucket,
    '${R2_ENDPOINT}': r2_endpoint,
}

for f in files:
    try:
        with open(f) as fh:
            content = fh.read()
        for placeholder, value in replacements.items():
            content = content.replace(placeholder, value)
        with open(f, 'w') as fh:
            fh.write(content)
        print(f"  ✓ {f}")
    except FileNotFoundError:
        print(f"  ! {f} (not found, skipping)")
PYEOF

echo ""
echo "Done! Review changes with: git diff"
echo "Then commit and push."
