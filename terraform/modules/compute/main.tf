# Compute Engine Instance for PostgreSQL
resource "google_compute_instance" "postgres_vm" {
  name         = "${var.environment}-postgres-vm"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["postgres-server", "allow-iap-ssh"]

  # Always Free eligible boot disk
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size_gb
      type  = "pd-standard" # Standard persistent disk for Always Free
    }
  }

  # Network configuration - INTERNAL IP ONLY
  network_interface {
    network    = var.network_id
    subnetwork = var.subnet_id

    # No access_config block = no external IP
    # This ensures the VM only has internal IP
  }

  # Metadata for SSH and startup script
  metadata = {
    enable-oslogin = "TRUE"
    # Startup script to install basic dependencies
    # Ansible will handle the actual PostgreSQL setup
    startup-script = <<-EOF
      #!/bin/bash
      set -e

      # Update system
      apt-get update
      apt-get install -y python3 python3-pip

      # Install Docker
      curl -fsSL https://get.docker.com -o get-docker.sh
      sh get-docker.sh

      # Add user to docker group
      usermod -aG docker ubuntu || true

      # Enable and start Docker
      systemctl enable docker
      systemctl start docker

      # Create directory for PostgreSQL data
      mkdir -p /var/lib/postgresql/data
      chmod 700 /var/lib/postgresql/data

      # Log completion
      echo "VM initialization complete" | tee /var/log/startup-complete.log
    EOF
  }

  # Service account with least privilege
  service_account {
    email  = var.service_account
    scopes = ["cloud-platform"]
  }

  # Allow stopping for maintenance
  allow_stopping_for_update = true

  # Shielded VM configuration (security best practice)
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # Labels for organization
  labels = {
    environment = var.environment
    role        = "database"
    managed_by  = "terraform"
  }

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"],
    ]
  }
}
