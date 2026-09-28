module "network" {
  source         = "./modules/network"
  compartment_id = var.compartment_id
  name_prefix    = var.name_prefix
  vcn_cidr       = var.vcn_cidr
  subnet_cidr    = var.subnet_cidr
  admin_cidr     = var.admin_cidr
}

module "compute" {
  source               = "./modules/compute"
  compartment_id       = var.compartment_id
  subnet_id            = module.network.subnet_id
  image_id             = data.oci_core_images.ubuntu_arm.images[0].id
  availability_domains = [for ad in data.oci_identity_availability_domains.ads.availability_domains : ad.name]
  ssh_public_key       = var.ssh_public_key
  nodes                = var.nodes
}

module "lb" {
  source           = "./modules/lb"
  compartment_id   = var.compartment_id
  subnet_id        = module.network.subnet_id
  name_prefix      = var.name_prefix
  node_private_ips = module.compute.private_ips
}
