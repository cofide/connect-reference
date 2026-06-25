variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the parent domain. When set, NS delegation records are created in Cloudflare. Requires the CLOUDFLARE_API_TOKEN environment variable."
  type        = string
  default     = null

  validation {
    condition     = var.cloudflare_zone_id == null || var.cloudflare_record_name != null
    error_message = "cloudflare_record_name must be set when cloudflare_zone_id is provided."
  }
}

variable "cloudflare_record_name" {
  description = "Name for the NS delegation records in Cloudflare, relative to the Cloudflare zone (e.g. 'mysubdomain' to delegate mysubdomain.example.com when the Cloudflare zone is example.com)."
  type        = string
  default     = null
}

provider "cloudflare" {
  # Configured via the CLOUDFLARE_API_TOKEN environment variable.
  # Only required when cloudflare_zone_id is set in common.local.hcl.

  # Dummy token to avoid init error when no cloudflare resources are being created.
  # The Cloudflare provider requires the token to be exactly 40 characters long
  # and contain only a-z, A-Z, 0-9, -, and _.
  api_token = var.cloudflare_zone_id == null ? "0000000000000000000000000000000000000000" : null
}

# NS delegation records in the parent Cloudflare zone. Only created when
# cloudflare_zone_id is set. Requires CLOUDFLARE_API_TOKEN in the environment.
resource "cloudflare_record" "ns" {
  for_each = var.cloudflare_zone_id != null ? {
    # Route53 always generates 4 nameservers.
    # This knowledge is hardcoded here otherwise the number of items to iterate over can't be known at plan time.
    0 = aws_route53_zone.this.name_servers[0],
    1 = aws_route53_zone.this.name_servers[1],
    2 = aws_route53_zone.this.name_servers[2],
    3 = aws_route53_zone.this.name_servers[3],
  } : {}
  zone_id = var.cloudflare_zone_id
  name    = var.cloudflare_record_name
  type    = "NS"
  content = each.value
  ttl     = 86400
}
