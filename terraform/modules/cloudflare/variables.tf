variable "domain" {
  description = "Domain name"
  type        = string
}

variable "cloud_run_url" {
  description = "Cloud Run service URL (without https://)"
  type        = string
}

variable "allowed_countries" {
  description = "List of country codes allowed to access (all others blocked)"
  type        = list(string)
  default     = ["ES", "AM"]
}
