/**
 * # spire/agent-iam-role
 *
 * Creates an IAM role for the SPIRE agent with AWS Secrets Manager permissions for
 * the aws_secretsmanager SVIDStore plugin. The plugin stores workload SVIDs as secrets
 * in Secrets Manager; the agent needs create, update, describe, and delete permissions
 * on secrets under the configured name prefix.
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  oidc_provider_url = var.oidc_provider_arn != null ? trimprefix(var.oidc_provider_arn, "arn:aws:iam::${local.account_id}:oidc-provider/") : null
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

resource "aws_iam_role" "spire_agent" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# --- Secrets Manager SVIDStore policy ---
#
# The plugin tags every secret it creates with spire-svid=true and validates that tag
# before updating or deleting existing secrets. Tag conditions therefore scope each
# statement precisely:
#   - CreateSecret: require the tag in the request so only tagged secrets can be created.
#   - DescribeSecret: StringEqualsIfExists so that the plugin can check whether a secret
#     exists before creating it — when the secret doesn't yet exist there is no resource
#     tag for IAM to evaluate, so StringEquals would deny the call.
#   - All other operations: require the tag on the resource.

data "aws_iam_policy_document" "secretsmanager" {
  statement {
    sid       = "CreateSVIDSecret"
    actions   = ["secretsmanager:CreateSecret"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/spire-svid"
      values   = ["true"]
    }
  }

  statement {
    sid       = "DescribeSVIDSecret"
    actions   = ["secretsmanager:DescribeSecret"]
    resources = ["*"]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:ResourceTag/spire-svid"
      values   = ["true"]
    }
  }

  statement {
    sid = "ManageSVIDSecrets"
    actions = [
      "secretsmanager:DeleteSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:RestoreSecret",
      "secretsmanager:TagResource",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/spire-svid"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy" "secretsmanager" {
  name   = "${var.role_name}-secretsmanager"
  role   = aws_iam_role.spire_agent.name
  policy = data.aws_iam_policy_document.secretsmanager.json
}

# --- EKS Pod Identity association ---

resource "aws_eks_pod_identity_association" "spire_agent" {
  count = var.iam_mode == "pod_identity" && var.cluster_name != null ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.spire_agent.arn
}
