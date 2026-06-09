/**
 * # dns
 *
 * Creates a Route53 hosted zone. The zone is used by cert-manager for DNS01
 * ACME challenges, ExternalDNS for DNS record management, the SPIRE OIDC discovery
 * provider, and the Connect trust bundle CloudFront distribution.
 */

data "aws_region" "current" {}

resource "aws_route53_zone" "this" {
  name = var.zone_name
}
