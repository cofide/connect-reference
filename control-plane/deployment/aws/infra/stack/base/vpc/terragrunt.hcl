include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  aws_region = include.root.locals.aws_region
  default_config = {
    vpc_cidr = "10.0.0.0/16"
    vpc_name = "cofide-connect-control-plane-aws-reference-arch"
    public_subnets = {
      "az-a" = {
        cidr_block        = "10.0.0.0/24"
        availability_zone = "${local.aws_region}a"
        name              = "public-${local.aws_region}a"
        tags = {
          "kubernetes.io/role/elb" = "1"
        }
      }
      "az-b" = {
        cidr_block        = "10.0.1.0/24"
        availability_zone = "${local.aws_region}b"
        name              = "public-${local.aws_region}b"
        tags = {
          "kubernetes.io/role/elb" = "1"
        }
      }
      "az-c" = {
        cidr_block        = "10.0.2.0/24"
        availability_zone = "${local.aws_region}c"
        name              = "public-${local.aws_region}c"
        tags = {
          "kubernetes.io/role/elb" = "1"
        }
      }
    }
    private_subnets = {
      "az-a" = {
        cidr_block        = "10.0.32.0/19"
        availability_zone = "${local.aws_region}a"
        name              = "private-${local.aws_region}a"
        tags = {
          "kubernetes.io/role/internal-elb" = "1"
        }
      }
      "az-b" = {
        cidr_block        = "10.0.64.0/19"
        availability_zone = "${local.aws_region}b"
        name              = "private-${local.aws_region}b"
        tags = {
          "kubernetes.io/role/internal-elb" = "1"
        }
      }
      "az-c" = {
        cidr_block        = "10.0.96.0/19"
        availability_zone = "${local.aws_region}c"
        name              = "private-${local.aws_region}c"
        tags = {
          "kubernetes.io/role/internal-elb" = "1"
        }
      }
    }
    intra_subnets = {
      "az-a" = {
        cidr_block        = "10.0.4.0/24"
        availability_zone = "${local.aws_region}a"
        name              = "intra-${local.aws_region}a"
      }
      "az-b" = {
        cidr_block        = "10.0.5.0/24"
        availability_zone = "${local.aws_region}b"
        name              = "intra-${local.aws_region}b"
      }
      "az-c" = {
        cidr_block        = "10.0.6.0/24"
        availability_zone = "${local.aws_region}c"
        name              = "intra-${local.aws_region}c"
      }
    }
    internet_gateway_name    = "cofide-connect-control-plane-aws-reference-arch"
    nat_gateway_name         = "cofide-connect-control-plane-aws-reference-arch"
    public_route_table_name  = "public-cofide-connect-control-plane-aws-reference-arch"
    private_route_table_name = "private-cofide-connect-control-plane-aws-reference-arch"
    intra_route_table_name   = "intra-cofide-connect-control-plane-aws-reference-arch"
  }
  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/vpc"
}

inputs = {
  vpc_cidr                 = local.merged_config.vpc_cidr
  vpc_name                 = local.merged_config.vpc_name
  public_subnets           = local.merged_config.public_subnets
  private_subnets          = local.merged_config.private_subnets
  intra_subnets            = local.merged_config.intra_subnets
  internet_gateway_name    = local.merged_config.internet_gateway_name
  nat_gateway_name         = local.merged_config.nat_gateway_name
  public_route_table_name  = local.merged_config.public_route_table_name
  private_route_table_name = local.merged_config.private_route_table_name
  intra_route_table_name   = local.merged_config.intra_route_table_name
}
