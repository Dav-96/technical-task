terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Enable required GCP APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "run.googleapis.com",
    "vpcaccess.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

# VPC Network
module "vpc" {
  source = "../../modules/vpc"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  vpc_cidr    = var.vpc_cidr

  depends_on = [google_project_service.required_apis]
}

# IAM Service Accounts
module "iam" {
  source = "../../modules/iam"

  project_id        = var.project_id
  service_accounts  = var.service_accounts
  sa_impersonations = var.sa_impersonations

  depends_on = [google_project_service.required_apis]
}

# Secret Manager for DB credentials
module "secrets" {
  source = "../../modules/secrets"
  project_id  = var.project_id
  environment = var.environment
  depends_on = [google_project_service.required_apis]
}

# Compute Engine VM for PostgreSQL
module "compute" {
  source = "../../modules/compute"

  project_id      = var.project_id
  region          = var.region
  zone            = var.zone
  environment     = var.environment
  machine_type    = var.vm_machine_type
  disk_size_gb    = var.vm_disk_size_gb
  network_id      = module.vpc.network_id
  subnet_id       = module.vpc.subnet_id
  service_account = module.iam.vm_service_account_email

  depends_on = [module.vpc]
}

# Artifact Registry for container images
resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "${var.app_name}-repo"
  description   = "Docker repository for ${var.app_name}"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Cloud Run Service (will be deployed via CI/CD)
# This resource creates the service but doesn't deploy the initial revision
module "cloud_run" {
  source = "../../modules/cloud_run"

  project_id       = var.project_id
  region           = var.region
  service_name     = var.app_name
  service_account  = module.iam.cloudrun_service_account_email
  vpc_connector_id = module.vpc.vpc_connector_id
  environment      = var.environment
  custom_domain    = var.domain

  depends_on = [
    module.vpc,
    module.iam,
    module.secrets,
    google_artifact_registry_repository.app
  ]
}

# Cloudflare CDN and DNS
module "cloudflare" {
  source = "../../modules/cloudflare"

  domain            = var.domain
  cloud_run_url     = replace(module.cloud_run.service_url, "https://", "")
  allowed_countries = var.allowed_countries

  depends_on = [module.cloud_run]
}

# Monitoring and Alerting
# module "monitoring" {
#   source = "../../modules/monitoring"

#   project_id                 = var.project_id
#   environment                = var.environment
#   cloud_run_service_name     = module.cloud_run.service_name
#   domain                     = "${var.subdomain}.${var.domain}"
#   notification_email         = var.notification_email
#   alert_5xx_threshold        = var.alert_5xx_threshold
#   alert_latency_threshold_ms = var.alert_latency_threshold_ms

#   depends_on = [
#     google_project_service.required_apis,
#     module.cloud_run
#   ]
# }