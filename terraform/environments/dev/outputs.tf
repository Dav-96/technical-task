output "vm_name" {
  description = "Name of the Compute Engine VM"
  value       = module.compute.vm_name
}

output "vm_internal_ip" {
  description = "Internal IP address of the VM"
  value       = module.compute.vm_internal_ip
}

output "vm_zone" {
  description = "Zone where the VM is located"
  value       = var.zone
}

output "cloud_run_url" {
  description = "URL of the Cloud Run service"
  value       = module.cloud_run.service_url
}

output "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  value       = module.cloud_run.service_name
}

output "artifact_registry_url" {
  description = "URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "vpc_connector_id" {
  description = "VPC Connector ID for Cloud Run"
  value       = module.vpc.vpc_connector_id
}

output "vm_service_account" {
  description = "Service account email for VM"
  value       = module.iam.vm_service_account_email
}

output "cloudrun_service_account" {
  description = "Service account email for Cloud Run"
  value       = module.iam.cloudrun_service_account_email
}

# output "uptime_check_id" {
#   description = "ID of the uptime check"
#   value       = module.monitoring.uptime_check_id
# }

# output "alert_policy_5xx_id" {
#   description = "ID of the 5xx alert policy"
#   value       = module.monitoring.alert_policy_5xx_id
# }

# output "alert_policy_latency_id" {
#   description = "ID of the latency alert policy"
#   value       = module.monitoring.alert_policy_latency_id
# }

output "iap_tunnel_command" {
  description = "Command to create IAP tunnel to database"
  value       = "gcloud compute start-iap-tunnel ${module.compute.vm_name} 5432 --local-host-port=localhost:5432 --zone=${var.zone} --project=${var.project_id}"
}

output "ssh_command" {
  description = "Command to SSH into the VM via IAP"
  value       = "gcloud compute ssh ${module.compute.vm_name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "ansible_inventory" {
  description = "Ansible inventory configuration"
  value = {
    vm_name        = module.compute.vm_name
    vm_internal_ip = module.compute.vm_internal_ip
    zone           = var.zone
    project_id     = var.project_id
  }
}
