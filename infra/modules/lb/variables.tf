variable "compartment_id" { type = string }
variable "subnet_id" { type = string }
variable "node_private_ips" {
  type        = list(string)
  description = "Private IPs of k3s nodes (Traefik backends)"
}
