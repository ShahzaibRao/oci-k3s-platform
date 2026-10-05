variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID"
  sensitive   = true
}

variable "compartment_id" {
  type        = string
  description = "Compartment OCID where all resources are created"
}

variable "region" {
  type        = string
  description = "OCI region"
  default     = "eu-frankfurt-1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for every resource display name"
  default     = "k3s"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key injected into both VMs at launch"
  sensitive   = true
}

variable "admin_cidr" {
  type        = string
  description = "IP/CIDR allowed for SSH (22) and kubectl (6443). LOCK THIS to your own IP (e.g. 39.40.1.2/32) before the first apply — 0.0.0.0/0 is only a placeholder default."
  default     = "0.0.0.0/0"
}

variable "domain_name" {
  type        = string
  description = "Apex domain managed in Cloudflare (wildcard cert + DNS records)"
  default     = "raoshahzaib.site"
}

variable "vcn_cidr" {
  type        = string
  description = "CIDR block for the VCN"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet (nodes + load balancer)"
  default     = "10.0.1.0/24"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID for domain_name (Dashboard → domain → Overview)"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token with Zone:DNS:Edit on the zone. Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "r2_access_key_id" {
  type        = string
  description = "Cloudflare R2 S3 API access key (Velero backups). Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "creatorwatch_database_url" {
  type        = string
  description = "Supabase Postgres URL for CreatorWatch license server. Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "creatorwatch_admin_token" {
  type        = string
  description = "CreatorWatch /admin login token. Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "creatorwatch_session_secret" {
  type        = string
  description = "CreatorWatch Flask session secret (stable). Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "keycloak_database_url" {
  type        = string
  description = "Supabase JDBC URL for Keycloak (with user+password). Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "grafana_oidc_secret" {
  type        = string
  description = "Keycloak client secret for Grafana OIDC. Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "grafana_admin_password" {
  type        = string
  description = "Grafana admin password. Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "grafana_google_client_id" {
  type        = string
  description = "Google OAuth client ID for Grafana. Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "grafana_google_client_secret" {
  type        = string
  description = "Google OAuth client secret for Grafana. Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "argocd_oidc_secret" {
  type        = string
  description = "Keycloak client secret for ArgoCD OIDC. Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "keycloak_admin_password" {
  type        = string
  description = "Keycloak admin console password. Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "creatorwatch_key_secret" {
  type        = string
  description = "CreatorWatch license key encryption secret — NEVER change after set. TF_VAR_ in CI."
  sensitive   = true
}

variable "r2_secret_access_key" {
  type        = string
  description = "Cloudflare R2 S3 API secret key (Velero backups). Never commit — TF_VAR_ in CI."
  sensitive   = true
}

variable "nodes" {
  type = map(object({
    ad_index                = number
    ocpus                   = number
    memory_in_gbs           = number
    boot_volume_size_in_gbs = number
    role                    = string # "server" | "agent" (informational; Ansible uses it)
    private_ip              = string # static private IP from subnet CIDR (10.0.1.0/24)
  }))
  description = "k3s nodes. Spread across ADs for availability."

  default = {
    "k3s-server" = {
      ad_index                = 0
      ocpus                   = 2
      memory_in_gbs           = 12
      boot_volume_size_in_gbs = 90
      role                    = "server"
      private_ip              = "10.0.1.10"
    }
    "k3s-agent" = {
      ad_index                = 1
      ocpus                   = 2
      memory_in_gbs           = 12
      boot_volume_size_in_gbs = 90
      role                    = "agent"
      private_ip              = "10.0.1.11"
    }
  }

  validation {
    condition     = alltrue([for n in var.nodes : n.ocpus >= 1 && n.ocpus <= 4])
    error_message = "Each node must be 1–4 OCPUs (Always Free total is 4)."
  }

  validation {
    condition     = sum([for n in var.nodes : n.ocpus]) <= 4
    error_message = "Total OCPUs across nodes must not exceed the Always Free limit of 4."
  }

  validation {
    condition     = sum([for n in var.nodes : n.boot_volume_size_in_gbs]) <= 200
    error_message = "Total boot volume size must not exceed the Always Free limit of 200 GB."
  }
}
