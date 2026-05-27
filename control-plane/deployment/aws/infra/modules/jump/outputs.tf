output "instance_id" {
  description = "Instance ID of the jump instance — use as the SSM session target."
  value       = aws_instance.jump.id
}

output "security_group_id" {
  description = "ID of the jump instance security group — reference in other units to allow jump access."
  value       = aws_security_group.jump.id
}
