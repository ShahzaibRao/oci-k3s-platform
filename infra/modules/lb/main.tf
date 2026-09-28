# One OCI Flexible Load Balancer (10 Mbps, Always Free) in front of Traefik.
# TCP passthrough on 80/443 — TLS terminates at Traefik (wildcard cert via cert-manager),
# so the LB never sees certificates and never needs renewal config.
resource "oci_load_balancer_load_balancer" "main" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-lb"
  shape          = "flexible"

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }

  subnet_ids = [var.subnet_id]
  is_private = false # public IP — Cloudflare DNS points here
}

# One backend set per port. ROUND_ROBIN across both nodes.
resource "oci_load_balancer_backend_set" "http" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "http-80"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "TCP"
    port              = 80
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

resource "oci_load_balancer_backend_set" "https" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "https-443"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "TCP"
    port              = 443
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

# Each node is a backend in both sets (private IP — traffic stays inside the VCN).
resource "oci_load_balancer_backend" "http" {
  for_each = var.node_private_ips

  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.http.name
  ip_address       = each.value
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_backend" "https" {
  for_each = var.node_private_ips

  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.https.name
  ip_address       = each.value
  port             = 443
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

# TCP listeners — raw passthrough, no TLS config on the LB.
resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "http-80"
  default_backend_set_name = oci_load_balancer_backend_set.http.name
  protocol                 = "TCP"
  port                     = 80
}

resource "oci_load_balancer_listener" "https" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "https-443"
  default_backend_set_name = oci_load_balancer_backend_set.https.name
  protocol                 = "TCP"
  port                     = 443
}
