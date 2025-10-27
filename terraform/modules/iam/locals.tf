# Local variable to flatten service account roles for iteration
locals {
  project_role_bindings = merge([
    for sa_key, sa_config in var.service_accounts : {
      for role in sa_config.roles : "${sa_key}-${role}" => {
        sa_key = sa_key
        role   = role
      }
    }
  ]...)
}