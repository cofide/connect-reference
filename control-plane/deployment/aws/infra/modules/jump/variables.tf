variable "vpc_id" {
  type        = string
  description = "ID of the VPC to deploy the jump instance into."
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet to deploy the jump instance into. Must be a private subnet with NAT gateway access for SSM connectivity."
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role and instance profile for the jump instance."
}

variable "sg_name" {
  type        = string
  description = "Name for the jump instance security group."
}

variable "instance_name" {
  type        = string
  description = "Name tag for the jump instance."
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for the jump instance."
}

variable "ami_id" {
  type        = string
  default     = null
  description = "AMI ID for the jump instance. When null, the latest Amazon Linux 2023 x86_64 AMI is used. Pin this to prevent unplanned instance replacement on apply."
}
