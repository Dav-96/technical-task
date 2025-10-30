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

### Option A: Local Development (Run Terraform Locally)

Follow steps 1-8 below to deploy everything from your laptop.

### Option B: CI/CD with GitHub Actions

For automated deployments via GitHub Actions, complete these **one-time bootstrap steps first**:

#### CI/CD Bootstrap (One-Time Setup)

These resources are created manually because they're needed **before** Terraform can run:

```bash
# 1. Create GCS bucket for Terraform state
gsutil mb -p YOUR_PROJECT_ID -l us-west1 gs://YOUR_PROJECT_ID-terraform-state
gsutil versioning set on gs://YOUR_PROJECT_ID-terraform-state

# 2. Create CI/CD service account
gcloud iam service-accounts create cicd-github-sa \
  --display-name="CI/CD Service Account" \
  --description="Service account for GitHub Actions CI/CD pipeline" \
  --project=YOUR_PROJECT_ID

# 3. Grant CI/CD SA all required roles
for role in \
  "roles/run.admin" \
  "roles/compute.admin" \
  "roles/monitoring.admin" \
  "roles/resourcemanager.projectIamAdmin" \
  "roles/secretmanager.admin" \
  "roles/vpcaccess.admin" \
  "roles/serviceusage.serviceUsageConsumer" \
  "roles/iam.serviceAccountViewer" \
  "roles/iam.serviceAccountUser" \
  "roles/artifactregistry.writer"; do
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:cicd-github-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="$role" \
    --condition=None
done

# 4. Grant CI/CD SA access to GCS state bucket
gsutil iam ch serviceAccount:cicd-github-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com:roles/storage.objectAdmin \
  gs://YOUR_PROJECT_ID-terraform-state

# 5. Create Workload Identity Federation pool and provider
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --project=YOUR_PROJECT_ID

gcloud iam workload-identity-pools providers create-oidc github \
  --location=global \
  --workload-identity-pool=github-pool \
  --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --project=YOUR_PROJECT_ID

# 6. Bind WIF to CI/CD service account
gcloud iam service-accounts add-iam-policy-binding \
  cicd-github-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GITHUB_USER/YOUR_REPO" \
  --project=YOUR_PROJECT_ID

# 7. Add GitHub repository secrets (Settings → Secrets and variables → Actions):
# WIF_PROVIDER: projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github
# WIF_SERVICE_ACCOUNT: cicd-github-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

**Note**: CI/CD SA is NOT in Terraform - it's bootstrap infrastructure created manually once.

---

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

### 5. Set Database Password

**CRITICAL**: This step must be completed before deploying the database or application!

```bash
# Generate a secure password or use your own
DB_PASSWORD="your-secure-password-here"

# Store password in Secret Manager
echo -n "$DB_PASSWORD" | gcloud secrets versions add dev-db-password \
  --data-file=- \
  --project=YOUR_PROJECT_ID

# Verify it was set correctly
gcloud secrets versions access latest --secret=dev-db-password \
  --project=YOUR_PROJECT_ID
```

> **Note**: Terraform creates Secret Manager secrets with placeholder values. Only the database password needs to be manually set. Other database connection details (host, port, database name, user) are configured as environment variables in the deployment pipeline.

### 6. Deploy Database

```bash
cd ../../../ansible
ansible-playbook -i inventory/hosts.ini playbooks/setup-postgres.yml \
  -e target_project=YOUR_PROJECT_ID \
  -e target_vm=dev-postgres-vm \
  -e target_zone=us-west1-a
```

### 7. Deploy Application (GitHub Actions)

Push to `main` branch triggers:
1. **terraform.yml**: Infrastructure changes
2. **deploy-app.yml**: Build → Artifact Registry → Cloud Run

### 8. Create Domain Mapping (Manual - Domain Ownership Required)

```bash
gcloud beta run domain-mappings create YOUR_DOMAIN \
  --service=hello-db-app \
  --region=us-west1 \
  --project=YOUR_PROJECT_ID
```

**Why manual?** Requires domain ownership verification via Search Console.

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

Automated workflows in `.github/workflows/`:
- **terraform.yml**: Runs `terraform plan` on PRs, `terraform apply` on merges to main
- **deploy-app.yml**: Builds Docker image, pushes to Artifact Registry, deploys to Cloud Run
- **ansible-database.yml**: Manual trigger to setup/restart/check database

**Prerequisites**: Complete "CI/CD Prerequisites (One-Time Setup)" section above before workflows can run.

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
# Delete domain mapping first (manual resource)
gcloud beta run domain-mappings delete YOUR_DOMAIN \
  --region=us-west1 \
  --project=YOUR_PROJECT_ID

# Destroy Terraform-managed infrastructure
cd terraform/environments/dev
source .envrc  # Load Cloudflare token
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