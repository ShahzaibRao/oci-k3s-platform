# OCI Free Load Balancer (10 Mbps) in front of Traefik.
# Distributes HTTP/HTTPS to both k3s nodes with health checks.

resource "oci_load_balancer_load_balancer" "k3s" {
  compartment_id = var.compartment_id
  display_name   = "k3s-lb"
  shape          = "flexible"
  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }
  subnet_ids = [var.subnet_id]
}

resource "oci_load_balancer_backend_set" "http" {
  load_balancer_id = oci_load_balancer_load_balancer.k3s.id
  name             = "http-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "TCP"
    port              = 80
    interval_ms       = 30000
    timeout_in_millis = 3000
    retries           = 3
  }
}

resource "oci_load_balancer_backend_set" "https" {
  load_balancer_id = oci_load_balancer_load_balancer.k3s.id
  name             = "https-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "TCP"
    port              = 443
    interval_ms       = 30000
    timeout_in_millis = 3000
    retries           = 3
  }
}

# Backends: both nodes, ports 80 and 443 (Traefik via svclb)
resource "oci_load_balancer_backend" "http" {
  for_each         = toset(var.node_private_ips)
  load_balancer_id = oci_load_balancer_load_balancer.k3s.id
  backendset_name  = oci_load_balancer_backend_set.http.name
  ip_address       = each.value
  port             = 80
}

resource "oci_load_balancer_backend" "https" {
  for_each         = toset(var.node_private_ips)
  load_balancer_id = oci_load_balancer_load_balancer.k3s.id
  backendset_name  = oci_load_balancer_backend_set.https.name
  ip_address       = each.value
  port             = 443
}

resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.k3s.id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.http.name
  port                     = 80
  protocol                 = "TCP"
}

resource "oci_load_balancer_listener" "https" {
  load_balancer_id         = oci_load_balancer_load_balancer.k3s.id
  name                     = "https-listener"
  default_backend_set_name = oci_load_balancer_backend_set.https.name
  port                     = 443
  protocol                 = "TCP"
}
