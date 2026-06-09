variable "vpc_cidr" {
  description = "IPv4 CIDR block for VPC"
  type        = string
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
}

variable "public_subnets" {
  description = "Map of public subnets to create. Resources in public subnets are assigned public IPs and are reachable from the internet via the internet gateway."
  type = map(object({
    cidr_block        = string
    availability_zone = string
    name              = string
    tags              = optional(map(string), {})
  }))
  default = {}
}

variable "internet_gateway_name" {
  description = "Name tag for the internet gateway"
  type        = string
  default     = ""
}

variable "public_route_table_name" {
  description = "Name tag for the public subnet route table"
  type        = string
  default     = ""
}

variable "private_subnets" {
  description = "Map of private subnets to create. Resources in private subnets have no public IPs and are not reachable from the internet, but can reach the internet via the NAT gateway."
  type = map(object({
    cidr_block        = string
    availability_zone = string
    name              = string
    tags              = optional(map(string), {})
  }))
  default = {}
}

variable "nat_gateway_name" {
  description = "Name tag for the NAT gateway"
  type        = string
  default     = ""
}

variable "private_route_table_name" {
  description = "Name tag for the private subnet route table"
  type        = string
  default     = ""
}

variable "intra_subnets" {
  description = "Map of intra subnets to create. Resources in intra subnets have no public IPs and no route to the internet."
  type = map(object({
    cidr_block        = string
    availability_zone = string
    name              = string
    tags              = optional(map(string), {})
  }))
  default = {}
}

variable "intra_route_table_name" {
  description = "Name tag for the intra subnet route table"
  type        = string
  default     = ""
}
