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

output "lb_public_ip" {
  description = "Public IP of the load balancer — point Cloudflare DNS here"
  value       = module.lb.public_ip
}
