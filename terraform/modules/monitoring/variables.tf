variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-west1"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service to monitor"
  type        = string
}

variable "domain" {
  description = "Domain name for uptime check"
  type        = string
}

variable "notification_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "alert_5xx_threshold" {
  description = "Threshold for 5xx error rate alert (count per minute)"
  type        = number
  default     = 5
}

variable "alert_latency_threshold_ms" {
  description = "Threshold for p95 latency alert (milliseconds)"
  type        = number
  default     = 1000
}
