variable "iam_admin_username" {
  type        = string
  default     = "iam_admin"
  description = "Name of the IAM admin database role to create. This role is used for all subsequent database administration after this unit is applied."
}
