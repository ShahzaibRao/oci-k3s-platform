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

# Master encryption key for the secrets (free tier: 20 keys included)
resource "oci_kms_key" "k3s" {
  compartment_id      = var.compartment_id
  display_name        = "${var.name_prefix}-secrets-key"
  management_endpoint = oci_kms_vault.k3s.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

# One oci_vault_secret per entry in var.secrets — add future secrets by
# adding a line to the secrets map in infra/main.tf, no module change needed.
#
# NOTE: for_each uses nonsensitive(keys(...)) because secret NAMES are not
# sensitive (only values are), and Terraform forbids sensitive for_each keys.
resource "oci_vault_secret" "secrets" {
  for_each       = toset(nonsensitive(keys(var.secrets)))
  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.k3s.id
  key_id         = oci_kms_key.k3s.id
  secret_name    = each.key

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.secrets[each.key])
  }
}
