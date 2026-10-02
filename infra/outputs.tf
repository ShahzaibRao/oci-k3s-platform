output "node_public_ips" {
  description = "Public IP per node (feeds Ansible inventory)"
  value       = module.compute.public_ips
}

output "node_private_ips" {
  description = "Private IP per node"
  value       = module.compute.private_ips
}

output "vcn_id" {
  value = module.network.vcn_id
}

output "subnet_id" {
  value = module.network.subnet_id
}

output "vault_id" {
  description = "OCID of the secrets vault (for External Secrets Operator ClusterSecretStore)"
  value       = module.vault.vault_id
}

output "lb_public_ip" {
  description = "Public IP of the k3s load balancer — point Cloudflare A records here"
  value       = module.lb.public_ip
}
