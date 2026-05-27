/**
 * # rds-instance
 *
 * Creates a PostgreSQL RDS instance in intra subnets (no public endpoint) with
 * KMS-encrypted storage, IAM database authentication enabled, and the master password
 * managed by Secrets Manager. Accepts a map of security groups to create ingress
 * rules from, allowing fine-grained access control without coupling the module to
 * specific callers.
 */

resource "aws_db_subnet_group" "this" {
  name       = var.subnet_group_name
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "rds" {
  name        = var.security_group_name
  description = "RDS PostgreSQL instance security group"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "rds_ingress" {
  for_each                     = var.ingress_security_groups
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = each.value.security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = each.value.description
}

resource "aws_kms_key" "rds_storage" {
  description             = "KMS key for RDS storage encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "rds_storage" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.rds_storage.key_id
}

resource "aws_kms_key" "rds_secret" {
  description             = "KMS key for RDS master user secret encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "rds_secret" {
  name          = var.secret_kms_key_alias
  target_key_id = aws_kms_key.rds_secret.key_id
}

data "aws_iam_policy_document" "rds_monitoring_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  count              = var.monitoring_interval > 0 ? 1 : 0
  name               = var.monitoring_role_name
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume_role.json

  lifecycle {
    precondition {
      condition     = var.monitoring_role_name != null
      error_message = "monitoring_role_name must be set when monitoring_interval > 0."
    }
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_parameter_group" "this" {
  name   = var.parameter_group_name
  family = "postgres${var.postgres_version}"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "immediate"
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.db_identifier
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.db_instance_class

  storage_type          = var.storage_type
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds_storage.arn

  username = var.db_username

  iam_database_authentication_enabled = true
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = aws_kms_key.rds_secret.arn
  publicly_accessible                 = false

  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az = var.multi_az

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.final_snapshot_identifier
  deletion_protection       = var.deletion_protection
}
