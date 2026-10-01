resource "oci_core_instance" "nodes" {
  for_each = var.nodes

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domains[each.value.ad_index]
  display_name        = each.key
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = var.image_id
    boot_volume_size_in_gbs = each.value.boot_volume_size_in_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = true
    hostname_label   = each.key
    private_ip       = each.value.private_ip
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  preserve_boot_volume = false
}
