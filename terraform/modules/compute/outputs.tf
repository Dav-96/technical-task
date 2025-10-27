output "vm_name" {
  description = "Name of the VM instance"
  value       = google_compute_instance.postgres_vm.name
}

output "vm_id" {
  description = "ID of the VM instance"
  value       = google_compute_instance.postgres_vm.id
}

output "vm_internal_ip" {
  description = "Internal IP address of the VM"
  value       = google_compute_instance.postgres_vm.network_interface[0].network_ip
}

output "vm_zone" {
  description = "Zone where the VM is located"
  value       = google_compute_instance.postgres_vm.zone
}

output "vm_self_link" {
  description = "Self link of the VM"
  value       = google_compute_instance.postgres_vm.self_link
}
