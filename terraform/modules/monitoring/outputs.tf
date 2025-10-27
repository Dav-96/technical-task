output "uptime_check_id" {
  description = "ID of the uptime check"
  value       = google_monitoring_uptime_check_config.app_uptime.uptime_check_id
}

output "notification_channel_id" {
  description = "ID of the notification channel"
  value       = google_monitoring_notification_channel.email.id
}

output "alert_policy_5xx_id" {
  description = "ID of the 5xx error rate alert policy"
  value       = google_monitoring_alert_policy.high_5xx_rate.id
}

output "alert_policy_latency_id" {
  description = "ID of the latency alert policy"
  value       = google_monitoring_alert_policy.high_latency.id
}

output "alert_policy_uptime_id" {
  description = "ID of the uptime check alert policy"
  value       = google_monitoring_alert_policy.uptime_check_failure.id
}
