# IAM Module - Service Accounts and Role Assignments
# Roles are configured via variables to avoid duplication

# Create service accounts from variable configuration
resource "google_service_account" "service_accounts" {
  for_each = var.service_accounts

  account_id   = each.value.account_id
  display_name = each.value.display_name
  description  = each.value.description
}

# Assign project-level IAM roles to service accounts
resource "google_project_iam_member" "sa_project_roles" {
  for_each = local.project_role_bindings

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.service_accounts[each.value.sa_key].email}"
}

# Allow service accounts to impersonate other service accounts (if needed)
resource "google_service_account_iam_member" "sa_impersonation" {
  for_each = var.sa_impersonations

  service_account_id = google_service_account.service_accounts[each.value.target_sa].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.service_accounts[each.value.source_sa].email}"
}