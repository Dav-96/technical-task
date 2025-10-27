# Service Account for Compute Engine VM (PostgreSQL host)
resource "google_service_account" "vm_sa" {
  account_id   = "${var.environment}-vm-sa"
  display_name = "Service Account for ${var.environment} PostgreSQL VM"
  description  = "Least-privilege service account for Compute Engine VM running PostgreSQL"
}

# VM Service Account IAM Roles (Least Privilege)
resource "google_project_iam_member" "vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}

resource "google_project_iam_member" "vm_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}

# Allow VM to read from Artifact Registry (if needed to pull containers)
resource "google_project_iam_member" "vm_artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}

# Service Account for Cloud Run
resource "google_service_account" "cloudrun_sa" {
  account_id   = "${var.environment}-cloudrun-sa"
  display_name = "Service Account for ${var.environment} Cloud Run"
  description  = "Least-privilege service account for Cloud Run application"
}

# Cloud Run Service Account IAM Roles
resource "google_project_iam_member" "cloudrun_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

resource "google_project_iam_member" "cloudrun_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

resource "google_project_iam_member" "cloudrun_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Allow Cloud Run to access secrets
resource "google_project_iam_member" "cloudrun_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Service Account for CI/CD (GitHub Actions)
resource "google_service_account" "cicd_sa" {
  account_id   = "${var.environment}-cicd-sa"
  display_name = "Service Account for ${var.environment} CI/CD"
  description  = "Service account for GitHub Actions CI/CD pipeline"
}

# CI/CD Service Account IAM Roles
resource "google_project_iam_member" "cicd_artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

resource "google_project_iam_member" "cicd_cloudrun_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# Allow CI/CD to act as Cloud Run service account
resource "google_service_account_iam_member" "cicd_act_as_cloudrun" {
  service_account_id = google_service_account.cloudrun_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# Allow CI/CD to read secrets for deployment
resource "google_project_iam_member" "cicd_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# Storage Admin for state management (if using GCS backend)
# Uncomment if using GCS for Terraform state
# resource "google_project_iam_member" "cicd_storage_admin" {
#   project = var.project_id
#   role    = "roles/storage.admin"
#   member  = "serviceAccount:${google_service_account.cicd_sa.email}"
# }
