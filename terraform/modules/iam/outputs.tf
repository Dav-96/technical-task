output "service_account_emails" {
  description = "Map of service account emails"
  value = {
    for k, v in google_service_account.service_accounts : k => v.email
  }
}

output "service_account_ids" {
  description = "Map of service account IDs"
  value = {
    for k, v in google_service_account.service_accounts : k => v.id
  }
}

# Convenience outputs for specific service accounts
output "vm_service_account_email" {
  description = "Email of the VM service account"
  value       = google_service_account.service_accounts["vm"].email
}

output "cloudrun_service_account_email" {
  description = "Email of the Cloud Run service account"
  value       = google_service_account.service_accounts["cloudrun"].email
}
