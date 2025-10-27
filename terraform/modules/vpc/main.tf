# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.environment}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC network for ${var.environment} environment"
}

# Subnet for compute resources
resource "google_compute_subnetwork" "private" {
  name          = "${var.environment}-private-subnet"
  ip_cidr_range = var.vpc_cidr
  region        = var.region
  network       = google_compute_network.main.id

  # Enable Private Google Access for services without public IPs
  private_ip_google_access = true

  # Secondary IP ranges for GKE if needed in future
  # secondary_ip_range {
  #   range_name    = "pods"
  #   ip_cidr_range = "10.1.0.0/16"
  # }
  # secondary_ip_range {
  #   range_name    = "services"
  #   ip_cidr_range = "10.2.0.0/16"
  # }
}

# Cloud Router for NAT
resource "google_compute_router" "main" {
  name    = "${var.environment}-router"
  region  = var.region
  network = google_compute_network.main.id

  bgp {
    asn = 64514
  }
}

# Cloud NAT for outbound internet access (VM needs to pull Docker images)
resource "google_compute_router_nat" "main" {
  name                               = "${var.environment}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Serverless VPC Access Connector for Cloud Run
resource "google_vpc_access_connector" "main" {
  name          = "${var.environment}-vpc-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28" # /28 is minimum for VPC connector
  network       = google_compute_network.main.name

  # e2-micro for connector (cost optimization)
  machine_type = "e2-micro"
  min_instances = 2
  max_instances = 3
}

# Firewall Rules

# Allow IAP for SSH
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.environment}-allow-iap-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP IP range
  source_ranges = ["35.235.240.0/20"]

  target_tags = ["allow-iap-ssh"]

  description = "Allow SSH from Cloud IAP"
}

# Allow internal communication within VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc_cidr, "10.8.0.0/28"] # Include VPC connector range

  description = "Allow all internal traffic within VPC"
}

# Allow PostgreSQL from VPC Connector (Cloud Run)
resource "google_compute_firewall" "allow_postgres_from_cloudrun" {
  name    = "${var.environment}-allow-postgres-cloudrun"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = ["10.8.0.0/28"] # VPC Connector range
  target_tags   = ["postgres-server"]

  description = "Allow PostgreSQL access from Cloud Run via VPC Connector"
}

# Deny all ingress by default (implicit, but explicit is better)
resource "google_compute_firewall" "deny_all_ingress" {
  name     = "${var.environment}-deny-all-ingress"
  network  = google_compute_network.main.name
  priority = 65534 # Lower priority (higher number) so other rules take precedence

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  description = "Deny all ingress traffic by default"
}
