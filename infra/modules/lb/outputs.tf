output "public_ip" {
  description = "Public IP of the load balancer (point Cloudflare A records here)"
  value       = oci_load_balancer_load_balancer.k3s.ip_address_details[0].ip_address
}
