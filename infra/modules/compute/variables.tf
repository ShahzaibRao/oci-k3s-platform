variable "compartment_id" { type = string }
variable "subnet_id" { type = string }
variable "image_id" { type = string }
variable "availability_domains" { type = list(string) }

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "nodes" {
  type = map(object({
    ad_index                = number
    ocpus                   = number
    memory_in_gbs           = number
    boot_volume_size_in_gbs = number
    role                    = string
    private_ip              = string
  }))
}
