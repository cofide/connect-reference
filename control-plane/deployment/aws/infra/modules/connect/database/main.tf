/**
 * # connect/database
 *
 * Creates a PostgreSQL database and login role for the Connect API, with `rds_iam`
 * granted so the role authenticates via short-lived IAM tokens at runtime rather than
 * a static password. Requires an `iam_admin` role with `rds_superuser` to exist — see
 * the `rds-iam-admin` module.
 */

resource "postgresql_role" "connect_api" {
  name  = var.connect_db_user
  login = true

  # Ignore the roles attribute to prevent conflict with postgresql_grant_role, which
  # manages role memberships independently. Without this, postgresql_role treats the
  # absence of a roles list as "remove all memberships" on every plan.
  lifecycle {
    ignore_changes = [roles]
  }
}

resource "postgresql_grant_role" "connect_api_rds_iam" {
  role       = postgresql_role.connect_api.name
  grant_role = "rds_iam"
}

resource "postgresql_database" "connect" {
  name = var.connect_db_name

  depends_on = [postgresql_role.connect_api]
}

resource "postgresql_grant" "connect_api_database" {
  database    = postgresql_database.connect.name
  role        = postgresql_role.connect_api.name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE", "TEMPORARY"]

  depends_on = [postgresql_database.connect]
}

resource "postgresql_grant" "connect_api_public_schema" {
  database    = postgresql_database.connect.name
  role        = postgresql_role.connect_api.name
  schema      = "public"
  object_type = "schema"
  privileges  = ["CREATE", "USAGE"]

  depends_on = [postgresql_database.connect]
}
