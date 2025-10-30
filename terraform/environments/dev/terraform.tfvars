# GCP Configuration
project_id = "test-dav-390413"
region     = "us-west1"
zone       = "us-west1-a"

# Domain Configuration
domain = "davits.store"

# Cloudflare Configuration
# Set CLOUDFLARE_API_TOKEN environment variable: export TF_VAR_cloudflare_api_token="your-api-token"

# Geo-restrictions (allowlist - only these countries can access)
allowed_countries = ["ES", "AM"] # Spain and Armenia

# Monitoring
notification_email         = "dav.naz.2001@gmail.com"
alert_5xx_threshold        = 5    # 5% of requests
alert_latency_threshold_ms = 1000 # 1000ms (1 second)

# Application
app_name = "hello-db-app"

# Service Accounts Configuration
# Customize service account names and roles as needed
service_accounts = {
  vm = {
    account_id   = "postgres-vm-sa"
    display_name = "PostgreSQL VM Service Account"
    description  = "Service account for Compute Engine VM running PostgreSQL"
    roles = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/artifactregistry.reader"
    ]
  }
  cloudrun = {
    account_id   = "app-cloudrun-sa"
    display_name = "Cloud Run Service Account"
    description  = "Service account for Cloud Run application"
    roles = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/cloudtrace.agent",
      "roles/secretmanager.secretAccessor"
    ]
  }
}

# Service Account Impersonations
# Note: CI/CD SA (cicd-github-sa) is created manually as a bootstrap resource (see README)
# It's not managed by Terraform since it's needed before Terraform can run
sa_impersonations = {}
