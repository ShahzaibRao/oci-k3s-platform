variable "compartment_id" { type = string }
variable "name_prefix" { type = string }
variable "vcn_cidr" { type = string }
variable "subnet_cidr" { type = string }

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed for SSH (22) and kubectl API (6443)"
}
