# versions.tf — toolchain pins. Everything reproducible, no surprises.
terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0.0, < 7.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0.0, < 6.0.0"
    }
  }

  # Backend is configured via -backend-config flags in CI (backend.hcl),
  # never hardcoded here — so local runs can't accidentally touch R2 state.
  # R2 credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars.
  # Local: terraform init -backend-config=backend.hcl (gitignored, never committed).
  backend "s3" {}
}
