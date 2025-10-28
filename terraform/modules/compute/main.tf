# Persistent disk for PostgreSQL data (survives VM deletion)
resource "google_compute_disk" "postgres_data" {
  name = "${var.environment}-postgres-data-disk"
  type = "pd-standard"
  zone = var.zone
  size = var.data_disk_size_gb

  labels = {
    environment = var.environment
    purpose     = "postgres-data"
    managed_by  = "terraform"
  }
}

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

  # Attach persistent data disk for PostgreSQL
  attached_disk {
    source      = google_compute_disk.postgres_data.id
    device_name = "postgres-data"
    mode        = "READ_WRITE"
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

      # Format and mount persistent disk for PostgreSQL data
      DEVICE_NAME="/dev/disk/by-id/google-postgres-data"
      MOUNT_POINT="/mnt/postgres-data"

      # Check if disk is already formatted
      if ! blkid $DEVICE_NAME; then
        echo "Formatting persistent disk..."
        mkfs.ext4 -F $DEVICE_NAME
      fi

      # Create mount point
      mkdir -p $MOUNT_POINT

      # Mount the disk
      mount $DEVICE_NAME $MOUNT_POINT

      # Add to fstab for automatic mounting on reboot
      if ! grep -q "$DEVICE_NAME" /etc/fstab; then
        echo "$DEVICE_NAME $MOUNT_POINT ext4 defaults 0 2" >> /etc/fstab
      fi

      # Create PostgreSQL data directory on persistent disk
      mkdir -p $MOUNT_POINT/data
      chmod 700 $MOUNT_POINT/data

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
