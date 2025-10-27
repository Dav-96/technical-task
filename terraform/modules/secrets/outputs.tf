output "db_password_secret_id" {
  description = "ID of the database password secret"
  value       = google_secret_manager_secret.db_password.secret_id
}

output "db_host_secret_id" {
  description = "ID of the database host secret"
  value       = google_secret_manager_secret.db_host.secret_id
}
