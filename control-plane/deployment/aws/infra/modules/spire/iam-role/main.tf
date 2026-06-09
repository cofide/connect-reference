/**
 * # spire/iam-role
 *
 * Creates an IAM role for the SPIRE server with RDS IAM authentication permission for
 * the SPIRE database user and KMS alias permissions for the key manager plugin. The
 * key-level permissions SPIRE needs (kms:Sign, kms:GetPublicKey, etc.) are granted
 * directly by each key's resource policy when SPIRE creates the key — no corresponding
 * IAM statements are required.
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # Strip the ARN prefix to get the bare OIDC provider URL for IRSA trust conditions.
  oidc_provider_url = var.oidc_provider_arn != null ? trimprefix(var.oidc_provider_arn, "arn:aws:iam::${local.account_id}:oidc-provider/") : null

  # KMS alias prefix used by the SPIRE key manager plugin for all keys it creates.
  kms_alias_prefix = "arn:aws:kms:${local.region}:${local.account_id}:alias/SPIRE_SERVER*"
}

# --- Trust policy ---

data "aws_iam_policy_document" "assume_role" {
  dynamic "statement" {
    for_each = var.iam_mode == "pod_identity" ? [1] : []
    content {
      actions = ["sts:AssumeRole", "sts:TagSession"]
      principals {
        type        = "Service"
        identifiers = ["pods.eks.amazonaws.com"]
      }
      dynamic "condition" {
        for_each = var.cluster_name != null ? [1] : []
        content {
          test     = "StringEquals"
          variable = "aws:RequestTag/eks-cluster-name"
          values   = [var.cluster_name]
        }
      }
      condition {
        test     = "StringEquals"
        variable = "aws:RequestTag/kubernetes-namespace"
        values   = [var.namespace]
      }
      condition {
        test     = "StringEquals"
        variable = "aws:RequestTag/kubernetes-service-account"
        values   = [var.service_account_name]
      }
    }
  }

  dynamic "statement" {
    for_each = var.iam_mode == "irsa" ? [1] : []
    content {
      actions = ["sts:AssumeRoleWithWebIdentity"]
      principals {
        type        = "Federated"
        identifiers = [var.oidc_provider_arn]
      }
      condition {
        test     = "StringEquals"
        variable = "${local.oidc_provider_url}:sub"
        values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
      }
      condition {
        test     = "StringEquals"
        variable = "${local.oidc_provider_url}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_role" "spire_server" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# --- KMS key manager policy ---
#
# SPIRE creates and manages its own asymmetric signing keys in KMS at runtime.
# It applies a default key policy at creation time that grants kms:* to its own
# IAM role on every key it creates. A direct principal grant in the key policy
# is sufficient without a corresponding IAM policy statement, so the IAM policy
# here only needs to cover actions that run before a key policy exists (CreateKey,
# TagResource) or that operate on alias resources rather than key resources.
# TagResource is in a separate statement scoped to key/* rather than * — see that
# statement for why it cannot be scoped to a specific key ARN.

data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "CreateAndListKeys"
    actions   = ["kms:CreateKey", "kms:ListKeys", "kms:ListAliases"]
    resources = ["*"]
  }

  statement {
    sid     = "TagKeys"
    actions = ["kms:TagResource"]
    # kms:TagResource is evaluated during CreateKey (before the key policy exists),
    # so it cannot be scoped to a specific key ARN. Scoped to key resources in this
    # account and region to prevent tagging keys in other accounts.
    resources = ["arn:aws:kms:${local.region}:${local.account_id}:key/*"]
  }

  statement {
    sid = "ManageKeyAliases"
    actions = [
      "kms:CreateAlias",
      "kms:UpdateAlias",
    ]
    # Only the alias resource is needed here. CreateKey sets the key policy
    # atomically, so the key-resource side of alias operations is covered by
    # the key policy's kms:* grant to this role.
    resources = [local.kms_alias_prefix]
  }

  statement {
    sid       = "DeleteKeyAliases"
    actions   = ["kms:DeleteAlias"]
    resources = [local.kms_alias_prefix]
  }

  # SPIRE's default key policy grants kms:* directly to this role on every key it creates,
  # so kms:DescribeKey, kms:GetPublicKey, kms:ScheduleKeyDeletion, and kms:Sign don't need
  # to appear here. IAM policy statements are only required when the key policy delegates
  # permission to the account root.
}

resource "aws_iam_role_policy" "kms" {
  name   = "${var.role_name}-kms"
  role   = aws_iam_role.spire_server.name
  policy = data.aws_iam_policy_document.kms.json
}

# --- RDS IAM authentication policy ---

data "aws_iam_policy_document" "rds" {
  count = var.db_resource_id != null && var.db_username != null ? 1 : 0

  statement {
    sid     = "ConnectAsSpire"
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:${local.region}:${local.account_id}:dbuser:${var.db_resource_id}/${var.db_username}",
    ]
  }
}

resource "aws_iam_role_policy" "rds" {
  count  = var.db_resource_id != null && var.db_username != null ? 1 : 0
  name   = "${var.role_name}-rds"
  role   = aws_iam_role.spire_server.name
  policy = data.aws_iam_policy_document.rds[0].json
}

# --- EKS Pod Identity association ---

resource "aws_eks_pod_identity_association" "spire_server" {
  count = var.iam_mode == "pod_identity" && var.cluster_name != null ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.spire_server.arn
}
