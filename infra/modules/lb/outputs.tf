output "public_ip" {
  description = "Public IP of the load balancer — Cloudflare DNS (apex + wildcard) points here"
  value       = oci_load_balancer_load_balancer.main.ip_address_details[0].ip_address
}

output "id" {
  value = oci_load_balancer_load_balancer.main.id
}
