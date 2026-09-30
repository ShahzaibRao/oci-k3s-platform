variable "compartment_id" { type = string }
variable "name_prefix" { type = string }

variable "secrets" {
  type        = map(string)
  description = "Secrets to store in the vault. Key = secret name in Vault, value = plaintext content (base64-encoded by the module). Add future secrets in infra/main.tf — no module change needed."
  sensitive   = true
  default     = {}
}
