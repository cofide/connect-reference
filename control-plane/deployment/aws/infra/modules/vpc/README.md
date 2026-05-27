<!-- BEGIN_TF_DOCS -->
# vpc

Creates a VPC with three subnet tiers: public (internet-routable via an internet
gateway), private (outbound-only via a regional NAT gateway, used for EKS nodes),
and intra (no internet route, used for RDS and other internal-only resources).

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
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.public_internet_from_private_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet_from_public_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.intra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.intra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.intra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_internet_gateway_name"></a> [internet\_gateway\_name](#input\_internet\_gateway\_name) | Name tag for the internet gateway | `string` | `""` | no |
| <a name="input_intra_route_table_name"></a> [intra\_route\_table\_name](#input\_intra\_route\_table\_name) | Name tag for the intra subnet route table | `string` | `""` | no |
| <a name="input_intra_subnets"></a> [intra\_subnets](#input\_intra\_subnets) | Map of intra subnets to create. Resources in intra subnets have no public IPs and no route to the internet. | <pre>map(object({<br/>    cidr_block        = string<br/>    availability_zone = string<br/>    name              = string<br/>    tags              = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_nat_gateway_name"></a> [nat\_gateway\_name](#input\_nat\_gateway\_name) | Name tag for the NAT gateway | `string` | `""` | no |
| <a name="input_private_route_table_name"></a> [private\_route\_table\_name](#input\_private\_route\_table\_name) | Name tag for the private subnet route table | `string` | `""` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | Map of private subnets to create. Resources in private subnets have no public IPs and are not reachable from the internet, but can reach the internet via the NAT gateway. | <pre>map(object({<br/>    cidr_block        = string<br/>    availability_zone = string<br/>    name              = string<br/>    tags              = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_public_route_table_name"></a> [public\_route\_table\_name](#input\_public\_route\_table\_name) | Name tag for the public subnet route table | `string` | `""` | no |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | Map of public subnets to create. Resources in public subnets are assigned public IPs and are reachable from the internet via the internet gateway. | <pre>map(object({<br/>    cidr_block        = string<br/>    availability_zone = string<br/>    name              = string<br/>    tags              = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | IPv4 CIDR block for VPC | `string` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name tag for the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_intra_subnet_ids"></a> [intra\_subnet\_ids](#output\_intra\_subnet\_ids) | Map of intra subnet IDs keyed by the subnet map key from var.intra\_subnets |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Map of private subnet IDs keyed by the subnet map key from var.private\_subnets |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Map of public subnet IDs keyed by the subnet map key from var.public\_subnets |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |
<!-- END_TF_DOCS -->