output "vm_service_account_email" {
  description = "Email of the VM service account"
  value       = google_service_account.vm_sa.email
}

output "vm_service_account_id" {
  description = "ID of the VM service account"
  value       = google_service_account.vm_sa.id
}

output "cloudrun_service_account_email" {
  description = "Email of the Cloud Run service account"
  value       = google_service_account.cloudrun_sa.email
}

output "cloudrun_service_account_id" {
  description = "ID of the Cloud Run service account"
  value       = google_service_account.cloudrun_sa.id
}

output "cicd_service_account_email" {
  description = "Email of the CI/CD service account"
  value       = google_service_account.cicd_sa.email
}

output "cicd_service_account_id" {
  description = "ID of the CI/CD service account"
  value       = google_service_account.cicd_sa.id
}
