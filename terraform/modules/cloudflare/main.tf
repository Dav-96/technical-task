terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Get zone information
data "cloudflare_zone" "domain" {
  name = var.domain
}

# DNS record pointing to Cloud Run
resource "cloudflare_record" "cloud_run" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "@"
  content = var.cloud_run_url
  type    = "CNAME"
  proxied = true
  comment = "Cloud Run service"
}

# DNS record for www subdomain
resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "www"
  content = var.domain
  type    = "CNAME"
  proxied = true
  comment = "WWW redirect"
}

# SSL/TLS configuration - Full (strict)
resource "cloudflare_zone_settings_override" "security" {
  zone_id = data.cloudflare_zone.domain.id

  settings {
    ssl                      = "full"
    always_use_https         = "on"
    automatic_https_rewrites = "on"
    min_tls_version          = "1.2"
    tls_1_3                  = "on"
    http2                    = "on"
    http3                    = "on"
  }
}

# Firewall rule for geo-restrictions (allowlist)
resource "cloudflare_firewall_rule" "geo_allowlist" {
  zone_id     = data.cloudflare_zone.domain.id
  description = "Allow traffic only from specific countries"
  filter_id   = cloudflare_filter.geo_allowlist.id
  action      = "block"
}

resource "cloudflare_filter" "geo_allowlist" {
  zone_id     = data.cloudflare_zone.domain.id
  description = "Filter for geo-allowlist (block all except allowed countries)"
  expression  = "not (ip.geoip.country in {${join(" ", [for country in var.allowed_countries : "\"${country}\""])}})"
}

# Cache rules for better performance
resource "cloudflare_page_rule" "cache_everything" {
  zone_id  = data.cloudflare_zone.domain.id
  target   = "${var.domain}/*"
  priority = 1

  actions {
    cache_level = "cache_everything"
    edge_cache_ttl = 7200
    browser_cache_ttl = 3600
  }
}

# Page rule for API endpoint (no caching)
resource "cloudflare_page_rule" "api_no_cache" {
  zone_id  = data.cloudflare_zone.domain.id
  target   = "${var.domain}/api*"
  priority = 2

  actions {
    cache_level = "bypass"
  }
}
