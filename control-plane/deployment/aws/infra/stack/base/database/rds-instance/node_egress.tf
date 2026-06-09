# Allows EKS worker nodes to connect to the RDS instance on port 5432.
# Kept here rather than in the rds-instance module so the module stays generic
# and free of EKS-specific concerns.

variable "node_security_group_id" {
  type        = string
  default     = null
  description = "Security group ID of the EKS worker nodes. When set, an egress rule is added allowing nodes to reach the RDS instance on port 5432."
}

resource "aws_vpc_security_group_egress_rule" "nodes_to_rds" {
  count                        = var.node_security_group_id != null ? 1 : 0
  security_group_id            = var.node_security_group_id
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow EKS worker nodes to connect to RDS"
}
