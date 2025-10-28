# Cloud Run Service
# Note: This creates the service structure, but the actual container image
# and environment variables will be managed via CI/CD (GitHub Actions)

resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = var.service_account

    # VPC connector for private database access
    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY" # Only route private IPs through VPC
    }

    scaling {
      min_instance_count = 0 # Scale to zero for cost savings
      max_instance_count = 10
    }

    containers {
      # Placeholder image - will be replaced by CI/CD
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = false
      }

      ports {
        container_port = 8080
        name           = "http1"
      }
    }

    timeout = "300s"
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  lifecycle {
    ignore_changes = [
      # CI/CD manages the container image and all configuration
      template[0].containers[0].image,
      template[0].containers[0].env,
      template[0].containers[0].resources,
      template[0].scaling,
      client,
      client_version,
    ]
  }
}

# Allow public access to Cloud Run service
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.app.name
  location = google_cloud_run_v2_service.app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Custom domain mapping
resource "google_cloud_run_domain_mapping" "custom_domain" {
  count    = var.custom_domain != "" ? 1 : 0
  name     = var.custom_domain
  location = var.region

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.app.name
  }
}
