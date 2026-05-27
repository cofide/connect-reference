data "aws_region" "current" {}

locals {
  use_direct_creds = var.db_username != null && var.db_password != null
  use_native_iam   = !local.use_direct_creds && var.aws_rds_iam_auth
  use_external_iam = !local.use_direct_creds && !var.aws_rds_iam_auth && var.db_actual_host != null
  db_actual_host   = var.db_actual_host != null ? var.db_actual_host : ""
}

data "external" "iam_auth_token" {
  count = local.use_external_iam ? 1 : 0

  program = [
    "bash", "-c",
    "TOKEN=$(aws rds generate-db-auth-token --hostname '${local.db_actual_host}' --port '${tostring(var.db_port)}' --username '${var.db_admin_username}' --region '${data.aws_region.current.region}') && printf '{\"token\":\"%s\"}' \"$TOKEN\""
  ]
}

provider "postgresql" {
  host             = var.db_host
  port             = var.db_port
  database         = "postgres"
  username         = local.use_direct_creds ? var.db_username : var.db_admin_username
  password         = local.use_direct_creds ? var.db_password : (local.use_external_iam ? data.external.iam_auth_token[0].result["token"] : null)
  aws_rds_iam_auth = local.use_native_iam
  sslmode          = "require"
  superuser        = false
}
