/**
 * # vpc
 *
 * Creates a VPC with three subnet tiers: public (internet-routable via an internet
 * gateway), private (outbound-only via a regional NAT gateway, used for EKS nodes),
 * and intra (no internet route, used for RDS and other internal-only resources).
 */

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc_name
  }
}

##################
# Public subnets #
##################

# Resources in public subnets have public IPs and can be reached from public internet.
resource "aws_subnet" "public" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true
  tags = merge(
    each.value.tags,
    {
      Name = each.value.name
    },
  )
}

resource "aws_internet_gateway" "this" {
  # Internet gateway is required only if there is a public or private subnet.
  count = length(var.public_subnets) > 0 || length(var.private_subnets) > 0 ? 1 : 0
  # VPC ID specified here so when destroying detachment+deletion is completed before VPC deletion
  # If using the separate aws_internet_gateway_attachment resource the detachment happens asynchronously which can
  # result in errors due to trying to delete the VPC before the gateway is detached.
  vpc_id = aws_vpc.this.id
  tags = {
    Name = var.internet_gateway_name
  }

  lifecycle {
    precondition {
      condition     = var.internet_gateway_name != ""
      error_message = "internet_gateway_name must be set when public or private subnets are defined."
    }
  }
}

resource "aws_route_table" "public" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags = {
    Name = var.public_route_table_name
  }

  lifecycle {
    precondition {
      condition     = var.public_route_table_name != ""
      error_message = "public_route_table_name must be set when public subnets are defined."
    }
  }
}

resource "aws_route" "public_internet_from_public_subnet" {
  count                  = length(var.public_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

###################
# Private subnets #
###################

# Resources in private subnets do not have public IPs and so cannot be reached from public internet, but can reach
# public internet themselves (via a NAT gateway).
resource "aws_subnet" "private" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone
  tags = merge(
    each.value.tags,
    {
      Name = each.value.name
    },
  )
}

# Regional NAT gateway running in auto mode.
# It will automatically expand into AZs as needed if workloads in that AZ have a route to the NAT gateway.
# If no workloads in an AZ require access to the NAT gateway it will reduce back down.
# This saves on costs (no need to permanently run a NAT gateway for every AZ with a private subnet).
# If a specific outbound IP list is required then an elastic IP can be pre-provisioned for each AZ the gateway may
# expand into.
#
# Regional NAT gateways are an AWS managed resource and do not require a public subnet for them to be deployed into,
# but they do still require the VPC within which they exist to have an internet gateway.
resource "aws_nat_gateway" "this" {
  # NAT gateway is required only if there is a private subnet.
  count             = length(var.private_subnets) > 0 ? 1 : 0
  vpc_id            = aws_vpc.this.id
  availability_mode = "regional"
  tags = {
    Name = var.nat_gateway_name
  }

  lifecycle {
    precondition {
      condition     = var.nat_gateway_name != ""
      error_message = "nat_gateway_name must be set when private subnets are defined."
    }
  }
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags = {
    Name = var.private_route_table_name
  }

  lifecycle {
    precondition {
      condition     = var.private_route_table_name != ""
      error_message = "private_route_table_name must be set when private subnets are defined."
    }
  }
}

resource "aws_route" "public_internet_from_private_subnet" {
  count                  = length(var.private_subnets) > 0 ? 1 : 0
  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[0].id
}

#################
# Intra subnets #
#################

# Resources in intra subnets do not have public IPs and so cannot be reached from public internet, and do not have a
# route to the public internet (no NAT gateway).
resource "aws_subnet" "intra" {
  for_each          = var.intra_subnets
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone
  tags = merge(
    each.value.tags,
    {
      Name = each.value.name
    },
  )
}

resource "aws_route_table" "intra" {
  count  = length(var.intra_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags = {
    Name = var.intra_route_table_name
  }

  lifecycle {
    precondition {
      condition     = var.intra_route_table_name != ""
      error_message = "intra_route_table_name must be set when intra subnets are defined."
    }
  }
}

resource "aws_route_table_association" "intra" {
  for_each       = aws_subnet.intra
  subnet_id      = each.value.id
  route_table_id = aws_route_table.intra[0].id
}
