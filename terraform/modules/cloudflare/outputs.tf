output "zone_id" {
  description = "Cloudflare zone ID"
  value       = data.cloudflare_zone.domain.id
}

output "nameservers" {
  description = "Cloudflare nameservers"
  value       = data.cloudflare_zone.domain.name_servers
}

output "domain_url" {
  description = "Full domain URL"
  value       = "https://${var.domain}"
}
