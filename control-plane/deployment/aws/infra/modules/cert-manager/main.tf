/**
 * # cert-manager
 *
 * Creates an IAM role for cert-manager with Route53 `ChangeResourceRecordSets`
 * permission scoped to a specific hosted zone, used for DNS01 ACME challenge
 * validation. Supports EKS Pod Identity (default) or IRSA.
 */

data "aws_iam_openid_connect_provider" "eks" {
  count = var.iam_mode == "irsa" ? 1 : 0
  arn   = var.oidc_provider_arn
}

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
        variable = "${trimprefix(data.aws_iam_openid_connect_provider.eks[0].url, "https://")}:sub"
        values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
      }
      condition {
        test     = "StringEquals"
        variable = "${trimprefix(data.aws_iam_openid_connect_provider.eks[0].url, "https://")}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

data "aws_iam_policy_document" "cert_manager" {
  # Required to poll for DNS propagation of ACME DNS01 challenges.
  statement {
    actions   = ["route53:GetChange"]
    resources = ["arn:aws:route53:::change/*"]
  }

  # Allow cert-manager to create and delete DNS01 challenge records in the managed zone only.
  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = ["arn:aws:route53:::hostedzone/${var.zone_id}"]
  }

  # Read-only access to find the hosted zone by name — cannot be scoped to a single zone.
  statement {
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cert_manager" {
  name   = var.policy_name
  policy = data.aws_iam_policy_document.cert_manager.json
}

resource "aws_iam_role" "cert_manager" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  role       = aws_iam_role.cert_manager.name
  policy_arn = aws_iam_policy.cert_manager.arn
}

resource "aws_eks_pod_identity_association" "cert_manager" {
  count           = var.iam_mode == "pod_identity" ? 1 : 0
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.cert_manager.arn
}
