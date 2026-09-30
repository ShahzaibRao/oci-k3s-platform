output "vault_id" {
  description = "OCID of the KMS vault (feeds External Secrets Operator ClusterSecretStore)"
  value       = oci_kms_vault.k3s.id
}

output "management_endpoint" {
  description = "Vault management endpoint"
  value       = oci_kms_vault.k3s.management_endpoint
}
