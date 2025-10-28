variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
}

variable "service_account" {
  description = "Service account email for Cloud Run"
  type        = string
}

variable "vpc_connector_id" {
  description = "VPC connector ID for private networking"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "custom_domain" {
  description = "Custom domain for Cloud Run service"
  type        = string
  default     = ""
}
