/**
 * # rds-iam-admin
 *
 * Creates a PostgreSQL role with `rds_superuser` and `rds_iam` for ongoing database
 * administration using IAM token authentication. This role must be created before any
 * other role is granted `rds_iam` — granting `rds_iam` triggers a pg_hba.conf reload
 * that makes password-based authentication unavailable over SSL.
 */

resource "postgresql_role" "iam_admin" {
  name            = var.iam_admin_username
  login           = true
  create_database = true

  # Ignore the roles attribute to prevent conflict with postgresql_grant_role, which
  # manages role memberships independently. Without this, postgresql_role treats the
  # absence of a roles list as "remove all memberships" on every plan.
  lifecycle {
    ignore_changes = [roles]
  }
}

resource "postgresql_grant_role" "iam_admin_superuser" {
  role       = postgresql_role.iam_admin.name
  grant_role = "rds_superuser"

  depends_on = [postgresql_role.iam_admin]
}

# Granting rds_iam triggers a pg_hba.conf reload in RDS. All three resources in
# this unit complete within the existing postgres session before the reload affects
# new connections, so postgres password auth remains usable for the duration of
# this apply. After apply, all SSL connections require IAM tokens.
resource "postgresql_grant_role" "iam_admin_rds_iam" {
  role       = postgresql_role.iam_admin.name
  grant_role = "rds_iam"

  depends_on = [postgresql_grant_role.iam_admin_superuser]
}
