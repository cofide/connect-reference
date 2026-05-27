/**
 * # aws-load-balancer-controller
 *
 * Creates an IAM role for the AWS Load Balancer Controller with the permissions
 * required to create and manage Network Load Balancers and Application Load Balancers
 * from Kubernetes Service and Ingress resources. Supports EKS Pod Identity (default)
 * or IRSA.
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

# iam_policy.json is the official IAM policy for the AWS Load Balancer Controller v2.x,
# sourced from https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json.
# Update this file when upgrading the controller to a new major version.
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name   = var.policy_name
  policy = file("${path.module}/iam_policy.json")
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  count           = var.iam_mode == "pod_identity" ? 1 : 0
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.aws_load_balancer_controller.arn
}
