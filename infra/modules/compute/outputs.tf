output "public_ips" {
  description = "Map of node name -> public IP (used to build Ansible inventory)"
  value       = { for k, v in oci_core_instance.nodes : k => v.public_ip }
}

output "private_ips" {
  description = "Map of node name -> private IP"
  value       = { for k, v in oci_core_instance.nodes : k => v.private_ip }
}
