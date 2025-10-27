# Notification Channel for Alerts
resource "google_monitoring_notification_channel" "email" {
  display_name = "${var.environment} Email Notifications"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }

  enabled = true
}

# Uptime Check for the Cloud Run service
resource "google_monitoring_uptime_check_config" "app_uptime" {
  display_name = "${var.environment}-${var.cloud_run_service_name}-uptime"
  timeout      = "10s"
  period       = "60s" # Check every 60 seconds

  http_check {
    path           = "/health"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.domain
    }
  }

  content_matchers {
    content = "ok"
    matcher = "CONTAINS_STRING"
  }

  checker_type = "STATIC_IP_CHECKERS"
}

# Alert Policy for 5xx Error Rate
resource "google_monitoring_alert_policy" "high_5xx_rate" {
  display_name = "${var.environment} High 5xx Error Rate"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "5xx error rate exceeds ${var.alert_5xx_threshold}%"

    condition_threshold {
      filter = <<-EOT
        resource.type="cloud_run_revision"
        AND resource.labels.service_name="${var.cloud_run_service_name}"
        AND metric.type="run.googleapis.com/request_count"
        AND metric.labels.response_code_class="5xx"
      EOT

      duration        = "300s" # 5 minutes
      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_5xx_threshold

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields = [
          "resource.service_name",
          "resource.revision_name"
        ]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "1800s" # Auto-close after 30 minutes

    notification_rate_limit {
      period = "300s" # Don't send more than 1 notification per 5 minutes
    }
  }

  documentation {
    content   = <<-EOT
      ## High 5xx Error Rate Alert

      The ${var.cloud_run_service_name} service is experiencing a high rate of 5xx errors (>${var.alert_5xx_threshold}%).

      ### Troubleshooting Steps:
      1. Check Cloud Run logs: `gcloud run services logs read ${var.cloud_run_service_name} --region=${var.region} --limit=50`
      2. Verify database connectivity from Cloud Run to VM
      3. Check VM health and Docker container status
      4. Review recent deployments for potential issues
      5. Check resource limits (CPU/Memory) on Cloud Run

      ### Quick Commands:
      ```bash
      # View recent logs
      gcloud run services logs tail ${var.cloud_run_service_name} --region=${var.region}

      # Check service status
      gcloud run services describe ${var.cloud_run_service_name} --region=${var.region}

      # Rollback to previous revision if needed
      gcloud run services update-traffic ${var.cloud_run_service_name} --to-revisions=<PREVIOUS_REVISION>=100 --region=${var.region}
      ```
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    environment = var.environment
    severity    = "critical"
  }
}

# Alert Policy for High Latency (p95)
resource "google_monitoring_alert_policy" "high_latency" {
  display_name = "${var.environment} High Request Latency (p95)"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "p95 latency exceeds ${var.alert_latency_threshold_ms}ms"

    condition_threshold {
      filter = <<-EOT
        resource.type="cloud_run_revision"
        AND resource.labels.service_name="${var.cloud_run_service_name}"
        AND metric.type="run.googleapis.com/request_latencies"
      EOT

      duration        = "300s" # 5 minutes
      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_latency_threshold_ms

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
        group_by_fields = [
          "resource.service_name",
          "resource.revision_name"
        ]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "1800s"

    notification_rate_limit {
      period = "300s"
    }
  }

  documentation {
    content   = <<-EOT
      ## High Latency Alert

      The ${var.cloud_run_service_name} service is experiencing high p95 latency (>${var.alert_latency_threshold_ms}ms).

      ### Troubleshooting Steps:
      1. Check Cloud Run performance metrics in Console
      2. Review database query performance
      3. Verify network connectivity between Cloud Run and database
      4. Check if Cloud Run instances are scaling properly
      5. Review application code for performance bottlenecks

      ### Quick Commands:
      ```bash
      # View service metrics
      gcloud monitoring timeseries list \
        --filter='metric.type="run.googleapis.com/request_latencies" AND resource.label.service_name="${var.cloud_run_service_name}"' \
        --format=json

      # Check current instance count
      gcloud run services describe ${var.cloud_run_service_name} --region=${var.region} --format='value(status.traffic[0].revisionName)'

      # SSH to database VM to check performance
      gcloud compute ssh <VM_NAME> --zone=<ZONE> --tunnel-through-iap
      ```
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    environment = var.environment
    severity    = "warning"
  }
}

# Alert Policy for Uptime Check Failure
resource "google_monitoring_alert_policy" "uptime_check_failure" {
  display_name = "${var.environment} Application Uptime Check Failed"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Uptime check for ${var.domain} failed"

    condition_threshold {
      filter = <<-EOT
        resource.type="uptime_url"
        AND metric.type="monitoring.googleapis.com/uptime_check/check_passed"
        AND metric.labels.check_id="${google_monitoring_uptime_check_config.app_uptime.uptime_check_id}"
      EOT

      duration        = "60s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields = [
          "resource.host"
        ]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = <<-EOT
      ## Application Downtime Alert

      The uptime check for ${var.domain} has failed.

      ### Immediate Actions:
      1. Check if the Cloud Run service is running
      2. Verify the custom domain mapping
      3. Check Cloudflare proxy status
      4. Review recent changes or deployments

      ### Quick Commands:
      ```bash
      # Check Cloud Run service status
      gcloud run services describe ${var.cloud_run_service_name} --region=${var.region}

      # Test endpoint directly
      curl https://${var.domain}/health

      # Check Cloud Run logs
      gcloud run services logs read ${var.cloud_run_service_name} --region=${var.region} --limit=50
      ```
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    environment = var.environment
    severity    = "critical"
  }
}
