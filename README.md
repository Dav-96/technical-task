# GCP Cloud Run + PostgreSQL Infrastructure

Production-ready infrastructure for a Flask application with PostgreSQL database, deployed on GCP with Cloudflare CDN and comprehensive monitoring.

## Architecture

```
Internet → Cloudflare (CDN/Geo-restriction) → Cloud Run (Flask App)
                                                     ↓
                                            VPC Serverless Connector
                                                     ↓
           Private VPC (10.0.0.0/24) ← Cloud NAT ← Compute Engine VM (PostgreSQL)
```

**Stack**: Terraform + Ansible + GitHub Actions + Flask + PostgreSQL + Cloudflare

## Repository Structure

```
.
├── .github/workflows/       # CI/CD pipelines
│   ├── terraform.yml        # Infrastructure deployment
│   ├── deploy-app.yml       # Application deployment
│   └── ansible-database.yml # Database configuration
├── ansible/
│   ├── inventory/hosts.ini
│   └── playbooks/setup-postgres.yml
├── app/
│   ├── app.py              # Flask application
│   ├── Dockerfile          # Single-stage build
│   └── requirements.txt
├── terraform/
│   ├── modules/
│   │   ├── vpc/            # Network + NAT + Connector
│   │   ├── iam/            # Service accounts (data-driven)
│   │   ├── secrets/        # Secret Manager placeholders
│   │   ├── compute/        # VM + persistent disk
│   │   ├── cloud_run/      # Cloud Run service + IAM
│   │   ├── cloudflare/     # DNS + WAF + caching
│   │   └── monitoring/     # Uptime + alerts
│   └── environments/dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       ├── backend.tf      # GCS remote state
│       └── .envrc          # Cloudflare token
├── CLAUDE.md               # Claude Code usage notes
└── README.md
```

## Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Compute | e2-micro VM (internal IP only) | PostgreSQL 16 in Docker |
| Application | Cloud Run | Flask app with auto-scaling 0-10 instances |
| Database | PostgreSQL 16-alpine | Persistent disk (10GB pd-standard) |
| CDN | Cloudflare | Caching, DDoS protection, geo-restriction |
| Networking | VPC + Cloud NAT + Serverless Connector | Private connectivity |
| Monitoring | Cloud Monitoring | Uptime checks + alert policies |
| CI/CD | GitHub Actions + WIF | Automated deployments |

## Key Design Decisions

### Security
- **VM internal IP only**: Database isolated from internet, accessed via Cloud IAP
- **Workload Identity Federation**: No service account keys in GitHub
- **Secret Manager API**: Credentials fetched at runtime, never hardcoded
- **Least-privilege IAM**: Data-driven service accounts with minimal roles
- **Geo-restriction**: Allowlist Spain (ES) + Armenia (AM) via Cloudflare WAF

### Infrastructure
- **Modular Terraform**: 6 modules (VPC, IAM, Secrets, Compute, Cloud Run, Monitoring)
- **Data-driven IAM**: Service accounts/roles defined in tfvars, not hardcoded
- **GCS remote state**: Versioned state in `gs://GCS_BUCKET_NAME`
- **Persistent disk**: Database survives VM recreation

### Connectivity
- **Cloud Run → PostgreSQL**: Via VPC Serverless Connector
- **VM outbound**: Cloud NAT for Docker image pulls
- **Developer access**: Cloud IAP TCP forwarding (no bastion needed)

## Monitoring Configuration



**Alert Policies**:
- **5xx Error Rate**: >5% of requests over 5 minutes → Critical
- **p95 Latency**: >1000ms over 5 minutes → Warning
- **Uptime Failure**: Health check fails for 60s → Critical

**Notification**: Email configured in `terraform.tfvars` (`notification_email` variable)

## Prerequisites

```bash
# Required tools
terraform >= 1.5.0
gcloud CLI
ansible >= 2.14
python 3.9+

# GCP APIs enabled
compute.googleapis.com
run.googleapis.com
vpcaccess.googleapis.com
artifactregistry.googleapis.com
secretmanager.googleapis.com
monitoring.googleapis.com
iam.googleapis.com
iap.googleapis.com
```

## Quick Start

### 1. Clone and Configure

```bash
# Clone repository
git clone https://github.com/YOUR_GITHUB_USER/YOUR_REPO.git
cd YOUR_REPO

# Copy example configuration files
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
cp .envrc.example .envrc

# Edit terraform.tfvars with your values:
# - project_id: Your GCP project ID
# - domain: Your domain name
# - notification_email: Your email for alerts

# Edit .envrc with your Cloudflare API token
# Get token from: https://dash.cloudflare.com/profile/api-tokens
```

### 2. Setup GCP Authentication

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 3. Create GCS Backend

```bash
gsutil mb -p YOUR_PROJECT_ID -l us-west1 gs://YOUR_PROJECT_ID-terraform-state
gsutil versioning set on gs://YOUR_PROJECT_ID-terraform-state
```

### 4. Deploy Infrastructure

```bash
cd terraform/environments/dev
source .envrc  # Load Cloudflare token
terraform init
terraform apply -auto-approve

# Outputs: VM IP, Cloud Run URL, IAP tunnel command
```

### 5. Deploy Database

```bash
cd ../../../ansible
ansible-playbook -i inventory/hosts.ini playbooks/setup-postgres.yml \
  -e target_project=YOUR_PROJECT_ID \
  -e target_vm=dev-postgres-vm \
  -e target_zone=us-west1-a
```

### 6. Deploy Application (GitHub Actions)

Push to `main` branch triggers:
1. **terraform.yml**: Infrastructure changes
2. **deploy-app.yml**: Build → Artifact Registry → Cloud Run
3. Domain mapping + SSL certificate provisioning

## Developer Database Access

### IAP TCP Forwarding (Recommended)

```bash
# Forward PostgreSQL port to localhost
gcloud compute start-iap-tunnel dev-postgres-vm 5432 \
  --local-host-port=localhost:5432 \
  --zone=us-west1-a \
  --project=YOUR_PROJECT_ID

# Connect with psql
psql -h localhost -p 5432 -U postgres -d postgres
```

### Direct SSH

```bash
# SSH via IAP
gcloud compute ssh dev-postgres-vm \
  --zone=us-west1-a \
  --tunnel-through-iap \
  --project=YOUR_PROJECT_ID

# Access container
sudo docker exec -it postgres psql -U postgres
```

## CI/CD Workflows

### Workload Identity Federation Setup (One-time)

```bash
# Create WIF pool and provider
gcloud iam workload-identity-pools create github-actions \
  --location=global --project=YOUR_PROJECT_ID

gcloud iam workload-identity-pools providers create-oidc github \
  --location=global --workload-identity-pool=github-actions \
  --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --project=YOUR_PROJECT_ID

# Bind service account
gcloud iam service-accounts add-iam-policy-binding \
  cicd-github-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions/attribute.repository/YOUR_GITHUB_USER/YOUR_REPO" \
  --project=YOUR_PROJECT_ID
```

### GitHub Secrets Required

```
WIF_PROVIDER: projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions/providers/github
WIF_SERVICE_ACCOUNT: cicd-github-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
CLOUDFLARE_API_TOKEN: (your cloudflare api token)
```

## Rollback Procedures

### Application Rollback

```bash
# List revisions
gcloud run revisions list --service=hello-db-app --region=us-west1

# Route 100% traffic to previous revision
gcloud run services update-traffic hello-db-app \
  --to-revisions=PREVIOUS_REVISION=100 \
  --region=us-west1
```

### Infrastructure Rollback

```bash
# Option 1: Terraform state rollback
terraform state pull > backup.tfstate
terraform state push previous-state.tfstate
terraform apply

# Option 2: Git revert
git revert <commit-hash>
git push origin main
```

## Cleanup & Cost Prevention

```bash
# Destroy all infrastructure
cd terraform/environments/dev
terraform destroy -auto-approve

# Verify resources deleted
gcloud compute instances list --project=YOUR_PROJECT_ID
gcloud run services list --project=YOUR_PROJECT_ID
gcloud compute disks list --project=YOUR_PROJECT_ID

# Delete GCS state bucket (optional)
gsutil -m rm -r gs://YOUR_PROJECT_ID-terraform-state
```

## Cloudflare Configuration

**DNS Records** (managed by Terraform):
```
yourdomain.com  A    216.239.32.21  (Proxied)
yourdomain.com  A    216.239.34.21  (Proxied)
yourdomain.com  A    216.239.36.21  (Proxied)
yourdomain.com  A    216.239.38.21  (Proxied)
www             CNAME yourdomain.com  (Proxied)
```

Note: These are Google's global anycast IPs for Cloud Run domain mappings

**WAF Rule** (Terraform `cloudflare_ruleset`):
```
Expression: (ip.geoip.country ne "ES" and ip.geoip.country ne "AM")
Action: Block
```

**Caching**:
- `/*`: Cache everything, edge TTL 2h, browser TTL 1h
- `/api*`: Bypass cache
- SSL/TLS: Full (not strict, Cloud Run uses Google certs)