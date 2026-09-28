# provider.tf — provider authentication.
#
# OCI: API-key auth via ~/.oci/config, written by CI from the
#   OCI_TENANCY_OCID / OCI_USER_OCID / OCI_FINGERPRINT / OCI_PRIVATE_KEY
#   secrets before init/plan/apply. (The v6 provider ignores those bare
#   env vars — it needs the config file or explicit block arguments.)
#   Region comes from var.region (default eu-frankfurt-1).
#   No credentials in code, ever. CI injects them from GitHub Secrets.
#
# Cloudflare: API token comes from a sensitive variable
#   (TF_VAR_cloudflare_api_token in CI). Token needs Zone:DNS:Edit on raoshahzaib.site.
provider "oci" {
  region = var.region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
