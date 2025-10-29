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

# DNS A records pointing to Cloud Run (for domain mapping)
# These IPs are provided by GCP when creating domain mapping
resource "cloudflare_record" "cloud_run_a" {
  for_each = toset([
    "216.239.32.21",
    "216.239.34.21",
    "216.239.36.21",
    "216.239.38.21"
  ])

  zone_id = data.cloudflare_zone.domain.id
  name    = "@"
  content = each.value
  type    = "A"
  proxied = false
  comment = "Cloud Run domain mapping"
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

# Firewall rule for geo-restrictions using WAF Custom Rules (Ruleset API)
resource "cloudflare_ruleset" "geo_allowlist" {
  zone_id     = data.cloudflare_zone.domain.id
  name        = "Geo-restriction allowlist"
  description = "Allow traffic only from Spain and Armenia"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "block"
    description = "Block all traffic except from ES and AM"
    expression  = "(ip.geoip.country ne \"ES\" and ip.geoip.country ne \"AM\")"
    enabled     = true
  }
}

# Cache rules for better performance
resource "cloudflare_page_rule" "cache_everything" {
  zone_id  = data.cloudflare_zone.domain.id
  target   = "${var.domain}/*"
  priority = 1

  actions {
    cache_level       = "cache_everything"
    edge_cache_ttl    = 7200
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
