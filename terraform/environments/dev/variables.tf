variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources (Always Free eligible: us-west1, us-central1, us-east1)"
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "GCP zone for compute resources"
  type        = string
  default     = "us-west1-a"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "domain" {
  description = "Root domain for the application"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "app"
}

# variable "cloudflare_zone_id" {
#   description = "Cloudflare Zone ID"
#   type        = string
# }

# variable "cloudflare_api_token" {
#   description = "Cloudflare API Token"
#   type        = string
#   sensitive   = true
# }

variable "allowed_countries" {
  description = "List of country codes allowed to access the application"
  type        = list(string)
  default     = ["ES", "AM"] # Spain and Armenia
}

variable "vm_machine_type" {
  description = "Machine type for the database VM (e2-micro for Always Free)"
  type        = string
  default     = "e2-micro"
}

variable "vm_disk_size_gb" {
  description = "Boot disk size in GB (30GB max for Always Free)"
  type        = number
  default     = 30
}

variable "alert_5xx_threshold" {
  description = "Threshold for 5xx error rate alert (percentage)"
  type        = number
  default     = 5
}

variable "alert_latency_threshold_ms" {
  description = "Threshold for p95 latency alert (milliseconds)"
  type        = number
  default     = 1000
}

variable "notification_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "hello-db-app"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC subnet"
  type        = string
  default     = "10.0.0.0/24"
}
