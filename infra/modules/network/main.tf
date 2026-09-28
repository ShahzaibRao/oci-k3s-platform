resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-vcn"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = "${var.name_prefix}vcn"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name_prefix}-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name_prefix}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name_prefix}-public-seclist"

  # Outbound: allow all
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # Intra-cluster: nodes must talk to each other on any port
  # (Cilium eBPF, kubelet 10250, k3s API 6443 internally, Longhorn, etc.)
  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr
  }

  # SSH: admin only (kept open for now; lockdown later via admin_cidr)
  ingress_security_rules {
    protocol = "6"
    source   = var.admin_cidr
    tcp_options {
      min = 22
      max = 22
    }
  }

  # kubectl API: admin only
  ingress_security_rules {
    protocol = "6"
    source   = var.admin_cidr
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # HTTP/HTTPS: world (ingress controller)
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # ICMP: ping / path MTU discovery
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name_prefix}-public-subnet"
  cidr_block     = var.subnet_cidr
  dns_label      = "publicsubnet"

  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.public.id]

  prohibit_public_ip_on_vnic = false
}
