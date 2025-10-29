output "db_password_secret_id" {
  description = "ID of the database password secret"
  value       = google_secret_manager_secret.db_password.secret_id
}
