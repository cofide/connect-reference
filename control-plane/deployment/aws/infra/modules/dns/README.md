<!-- BEGIN_TF_DOCS -->
# dns

Creates a Route53 hosted zone. The zone is used by cert-manager for DNS01
ACME challenges, ExternalDNS for DNS record management, the SPIRE OIDC discovery
provider, and the Connect trust bundle CloudFront distribution.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Name of the Route53 hosted zone to create (e.g. example.com). | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | Name servers for the Route53 hosted zone. Add these as NS records in the parent domain if not using Cloudflare delegation. |
| <a name="output_region"></a> [region](#output\_region) | AWS region in which the hosted zone is managed |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | ID of the Route53 hosted zone |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | Name of the Route53 hosted zone |
<!-- END_TF_DOCS -->