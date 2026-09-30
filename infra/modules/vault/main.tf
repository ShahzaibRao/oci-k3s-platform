# OCI Vault for Kubernetes secrets (replaces Sealed Secrets).
#
# WHY: Sealed Secrets keeps its private key inside the cluster. If the
# cluster is destroyed, old SealedSecrets become undecryptable unless the
# key was backed up. OCI Vault keeps secrets OUTSIDE the cluster — a fresh
# cluster just pulls them again via External Secrets Operator. No key to
# back up, no chicken-and-egg on rebuild.

resource "oci_kms_vault" "k3s" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-secrets-vault"
  vault_type     = "DEFAULT" # free tier
}

# One oci_vault_secret per entry in var.secrets — add future secrets by
# adding a line to the secrets map in infra/main.tf, no module change needed.
resource "oci_vault_secret" "secrets" {
  for_each       = var.secrets
  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.k3s.id
  secret_name    = each.key

  secret_content {
    content_type = "BASE64"
    content      = base64encode(each.value)
  }
}
