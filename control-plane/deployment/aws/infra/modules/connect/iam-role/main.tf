/**
 * # connect/iam-role
 *
 * Creates an IAM role for the Connect API that authenticates using SPIFFE JWT SVIDs
 * issued by the SPIRE server. The role grants RDS IAM authentication for the Connect
 * database user and S3 write access to the trust bundle bucket. Registers the SPIRE
 * OIDC discovery endpoint as an AWS IAM identity provider — the endpoint must be live
 * and reachable at apply time.
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

# --- SPIRE OIDC provider registration ---

data "tls_certificate" "spire_oidc" {
  url = "https://${var.spire_oidc_domain}"
}

resource "aws_iam_openid_connect_provider" "spire" {
  url            = "https://${var.spire_oidc_domain}"
  client_id_list = ["sts.amazonaws.com"]

  # AWS validates JWKS endpoint TLS against its own trusted CA library for public CA
  # certs (e.g. Let's Encrypt) and ignores this thumbprint in that case. The thumbprint
  # is only used as a fallback for private/unknown CAs. The last cert in the chain is the
  # top intermediate/root CA, which is what AWS expects if it does fall back to this value.
  thumbprint_list = [data.tls_certificate.spire_oidc.certificates[length(data.tls_certificate.spire_oidc.certificates) - 1].sha1_fingerprint]
}

# --- Trust policy ---

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.spire.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.spire_oidc_domain}:sub"
      values   = [var.spiffe_id]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.spire_oidc_domain}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "connect_api" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# --- S3 + KMS policy ---

data "aws_iam_policy_document" "s3" {
  count = var.bundle_bucket_arn != null ? 1 : 0

  statement {
    sid = "ManageBundles"
    actions = [
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:DeleteObject",
    ]
    resources = ["${var.bundle_bucket_arn}/*"]
  }

  statement {
    sid       = "ListBundles"
    actions   = ["s3:ListBucket"]
    resources = [var.bundle_bucket_arn]
  }

  dynamic "statement" {
    for_each = var.bundle_bucket_kms_key_arn != null ? [1] : []
    content {
      sid = "DecryptBundleBucketObjects"
      actions = [
        "kms:GenerateDataKey",
      ]
      resources = [var.bundle_bucket_kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "s3" {
  count  = var.bundle_bucket_arn != null ? 1 : 0
  name   = "${var.role_name}-s3"
  role   = aws_iam_role.connect_api.name
  policy = data.aws_iam_policy_document.s3[0].json
}

# --- RDS IAM authentication policy ---

data "aws_iam_policy_document" "rds" {
  count = var.db_resource_id != null && var.db_username != null ? 1 : 0

  statement {
    sid     = "ConnectAsConnectApi"
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:${local.region}:${local.account_id}:dbuser:${var.db_resource_id}/${var.db_username}",
    ]
  }
}

resource "aws_iam_role_policy" "rds" {
  count  = var.db_resource_id != null && var.db_username != null ? 1 : 0
  name   = "${var.role_name}-rds"
  role   = aws_iam_role.connect_api.name
  policy = data.aws_iam_policy_document.rds[0].json
}
