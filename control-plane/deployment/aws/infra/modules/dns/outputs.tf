output "region" {
  description = "AWS region in which the hosted zone is managed"
  value       = data.aws_region.current.region
}

output "zone_id" {
  description = "ID of the Route53 hosted zone"
  value       = aws_route53_zone.this.zone_id
}

output "zone_name" {
  description = "Name of the Route53 hosted zone"
  value       = aws_route53_zone.this.name
}

output "name_servers" {
  description = "Name servers for the Route53 hosted zone. Add these as NS records in the parent domain if not using Cloudflare delegation."
  value       = aws_route53_zone.this.name_servers
}
