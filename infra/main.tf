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
  source         = "./modules/lb"
  compartment_id = var.compartment_id
  subnet_id      = module.network.subnet_id
  # Static private IPs from var.nodes (server 10.0.1.10, agent 10.0.1.11)
  node_private_ips = [for n in var.nodes : n.private_ip]
}

module "vault" {
  source         = "./modules/vault"
  compartment_id = var.compartment_id
  name_prefix    = var.name_prefix

  # Add future secrets here as "vault-secret-name" = var.some_variable.
  # Each value comes from TF_VAR_* in CI — never commit plaintext.
  secrets = {
    "velero-r2-credentials" = join("\n", [
      "[default]",
      "aws_access_key_id=${var.r2_access_key_id}",
      "aws_secret_access_key=${var.r2_secret_access_key}",
    ])
    "cloudflare-api-token" = var.cloudflare_api_token
  }
}
