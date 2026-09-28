variable "compartment_id" { type = string }
variable "subnet_id" { type = string }
variable "name_prefix" { type = string }

variable "node_private_ips" {
  type        = map(string)
  description = "Map of node name -> private IP. Both become LB backends."
}
