# GCP Cloud Run + PostgreSQL Infrastructure

This repository contains Infrastructure as Code (IaC) for deploying a Cloud Run application connected to a PostgreSQL database running on a Compute Engine VM with Cloudflare CDN integration.

## Architecture

```

```

### Components

- **Compute Engine VM (e2-micro)**: Hosts PostgreSQL in Docker (internal IP only)
- **Cloud Run**: Runs the application container with auto-scaling
- **VPC & Networking**: Private networking with Cloud NAT for outbound traffic
- **Cloudflare**: CDN, DDoS protection, and geo-restriction (Spain + Armenia)
- **Cloud Monitoring**: Uptime checks and alerting policies

## Key Design Decisions

### Infrastructure
- **VM with internal IP only**: Enhances security by preventing direct internet access
- **Cloud NAT**: Allows VM to pull Docker images without public IP
- **VPC with private subnets**: Isolates database traffic
- **Workload Identity**: Secure service-to-service authentication without key files

### Database Connectivity
- **PostgreSQL in Docker**: Easier management and version control
- **Internal-only access**: No public load balancer or external IP
- **Developer access options**:
  1. Cloud IAP for TCP forwarding (recommended)
  2. Cloud Shell with internal connectivity
  3. Bastion host for persistent connections

### Security
- **Least-privilege IAM**: Each service account has minimal required permissions
- **Secret Manager**: Stores database credentials and sensitive configuration
- **Cloudflare geo-restriction**: Limits access to Spain and Armenia
- **Private networking**: Database never exposed to internet

### Observability
- **Uptime checks**: Monitor application availability
- **Alert policies**:
  - 5xx error rate > [THRESHOLD]% over 5 minutes
  - p95 latency > [THRESHOLD]ms over 5 minutes

## Prerequisites

- Google Cloud Platform account with billing enabled
- Cloudflare account with a domain configured
- Tools installed:
  - `terraform` >= 1.5.0
  - `gcloud` CLI
  - `ansible` >= 2.14
  - `docker` (for local testing)

## Environment Variables

Create a `terraform/environments/dev/terraform.tfvars` file (not committed):

```hcl
project_id          = "your-gcp-project-id"
region              = "us-west1"  # Always Free eligible region
zone                = "us-west1-a"
domain              = "yourdomain.com"
subdomain           = "app"
cloudflare_zone_id  = "your-cloudflare-zone-id"
allowed_countries   = ["ES", "YOUR_COUNTRY_CODE"]
db_password         = "secure-password-here"  # Better: use Secret Manager
```

## Deployment Instructions

### 1. Initial Setup

```bash
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set your project
export PROJECT_ID="your-gcp-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  vpcaccess.googleapis.com \
  secretmanager.googleapis.com \
  monitoring.googleapis.com
```

### 2. Configure GitHub Secrets

Add these secrets to your GitHub repository:

- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SA_KEY`: Service account key JSON for CI/CD
- `CLOUDFLARE_API_TOKEN`: Cloudflare API token with DNS edit permissions
- `CLOUDFLARE_ZONE_ID`: Your Cloudflare zone ID
- `DB_PASSWORD`: PostgreSQL password

### 3. Deploy Infrastructure

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply

# Note the outputs (VM IP, Cloud Run URL, etc.)
```

### 4. Configure Database with Ansible

```bash
cd ../../../ansible

# The inventory is auto-generated from Terraform outputs
ansible-playbook -i inventory/gcp.yml playbooks/setup-postgres.yml
```

### 5. Deploy Application via GitHub Actions

Push to the `main` branch to trigger CI/CD:
- Builds Docker image
- Pushes to Artifact Registry
- Deploys to Cloud Run
- Updates Cloudflare DNS

## CI/CD Pipeline

GitHub Actions workflows:

- **terraform.yml**: Validates and applies infrastructure changes
- **app-deploy.yml**: Builds and deploys application
- **cloudflare-dns.yml**: Manages DNS records via Cloudflare API

## Developer Access to Database

Since the PostgreSQL VM has no public IP, use one of these methods:

### Option 1: Cloud IAP TCP Forwarding (Recommended)

```bash
# Forward port 5432 from VM to localhost
gcloud compute start-iap-tunnel <VM_NAME> 5432 \
  --local-host-port=localhost:5432 \
  --zone=<ZONE>

# Connect from your local machine
psql -h localhost -p 5432 -U postgres -d appdb
```

### Option 2: Cloud Shell

```bash
# SSH into VM via internal IP (from Cloud Shell)
gcloud compute ssh <VM_NAME> --zone=<ZONE> --tunnel-through-iap

# Once on VM
docker exec -it postgres psql -U postgres -d appdb
```

## Monitoring & Alerts

Access monitoring dashboards:

```bash
# Open Cloud Monitoring
gcloud monitoring dashboards list

# View alert policies
gcloud alpha monitoring policies list
```

Alert thresholds:
- **5xx errors**: > X% of requests over 5 minutes
- **p95 latency**: > Xms over 5 minutes

## Rollback Procedures

### Application Rollback

```bash
# List Cloud Run revisions
gcloud run revisions list --service=<SERVICE_NAME> --region=<REGION>

# Rollback to previous revision
gcloud run services update-traffic <SERVICE_NAME> \
  --to-revisions=<PREVIOUS_REVISION>=100 \
  --region=<REGION>
```

### Infrastructure Rollback

```bash
# Revert to previous Terraform state
cd terraform/environments/dev
terraform state pull > backup.tfstate

# Review git history and checkout previous version
git checkout <PREVIOUS_COMMIT> -- terraform/

terraform plan
terraform apply
```

## Cleanup & Destroy

**⚠️ Warning**: This will destroy all resources and data.

```bash
# Destroy all infrastructure
cd terraform/environments/dev
terraform destroy

# Verify all resources are deleted
gcloud compute instances list
gcloud run services list
gcloud monitoring policies list
```

## Repository Structure

```
.
├── .github/
│   └── workflows/          # GitHub Actions CI/CD pipelines
├── ansible/
│   ├── inventory/          # Dynamic inventory for GCP
│   ├── playbooks/          # Ansible playbooks
│   └── roles/              # Reusable Ansible roles
├── app/                    # Application source code
│   ├── Dockerfile
│   └── src/
├── docs/                   # Additional documentation
├── scripts/                # Helper scripts
└── terraform/
    ├── modules/            # Reusable Terraform modules
    └── environments/
        └── dev/            # Development environment

```
