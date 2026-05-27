# Allows the SSM jump instance to forward TCP connections to the RDS instance
# on port 5432. Kept here rather than in the rds-instance module so the module
# stays generic and free of jump-instance-specific concerns.

variable "jump_security_group_id" {
  type        = string
  default     = null
  description = "Security group ID of the SSM jump instance. When set, an egress rule is added allowing it to reach the RDS instance on port 5432."
}

resource "aws_vpc_security_group_egress_rule" "jump_to_rds" {
  count                        = var.jump_security_group_id != null ? 1 : 0
  security_group_id            = var.jump_security_group_id
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow SSM jump instance to forward connections to RDS"
}
