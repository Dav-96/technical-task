variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "service_accounts" {
  description = "Map of service accounts to create with their roles"
  type = map(object({
    account_id   = string
    display_name = string
    description  = string
    roles        = list(string)
  }))
}

variable "sa_impersonations" {
  description = "Map of service account impersonation permissions"
  type = map(object({
    source_sa = string
    target_sa = string
  }))
  default = {}
}
