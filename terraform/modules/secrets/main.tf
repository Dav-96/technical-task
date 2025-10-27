# Secret Manager Secrets
# Note: Secret values will be manually populated via GCP Console UI for security
# This only creates the secret structure, not the actual sensitive values

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.environment}-db-password"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_secret_manager_secret" "db_host" {
  secret_id = "${var.environment}-db-host"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Placeholder secret version to satisfy Terraform
# Will be overwritten when you manually set the value in GCP Console
resource "google_secret_manager_secret_version" "db_password_placeholder" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = "REPLACE_ME_IN_GCP_CONSOLE"

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_version" "db_host_placeholder" {
  secret      = google_secret_manager_secret.db_host.id
  secret_data = "REPLACE_ME_IN_GCP_CONSOLE"

  lifecycle {
    ignore_changes = [secret_data]
  }
}
