/**
 * # eks-cluster
 *
 * Creates an EKS cluster with managed node groups, KMS encryption for Kubernetes
 * secrets, and managed add-ons (CoreDNS, kube-proxy, VPC CNI, EKS Pod Identity
 * Agent). Supports a private API server endpoint accessed via an SSM jump instance,
 * or a public endpoint with optional CIDR restrictions.
 */

# 1. IAM Roles & Security Hardening

# --- CONTROL PLANE IAM ---
resource "aws_iam_role" "cluster" {
  name               = var.cluster_role_name
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# --- NODE GROUP IAM ---
resource "aws_iam_role" "nodes" {
  name               = var.node_role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Mandatory policies for Managed Node Groups
resource "aws_iam_role_policy_attachment" "nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

# 2. Security Groups

resource "aws_security_group" "eks_cluster" {
  name        = var.cluster_sg_name
  description = "EKS control plane security group"
  vpc_id      = var.vpc_id
  tags        = { Name = var.cluster_sg_name }
}

resource "aws_security_group" "eks_nodes" {
  name        = var.node_sg_name
  description = "EKS worker node security group"
  vpc_id      = var.vpc_id
  tags        = { Name = var.node_sg_name }
}

# --- Cluster SG rules ---

# Ingress: nodes → control plane (API server)
resource "aws_vpc_security_group_ingress_rule" "cluster_ingress_from_nodes" {
  description                  = "Allow worker nodes to reach the API server"
  security_group_id            = aws_security_group.eks_cluster.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# Ingress: SSM jump instance → control plane (API server)
resource "aws_vpc_security_group_ingress_rule" "cluster_ingress_from_jump" {
  count                        = var.jump_security_group_id != null ? 1 : 0
  description                  = "Allow SSM jump instance to reach the API server"
  security_group_id            = aws_security_group.eks_cluster.id
  referenced_security_group_id = var.jump_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# Egress: control plane → nodes (kubelet API)
resource "aws_vpc_security_group_egress_rule" "cluster_egress_to_nodes_kubelet" {
  description                  = "Allow control plane to reach kubelet on nodes"
  security_group_id            = aws_security_group.eks_cluster.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}

# Egress: control plane → nodes (admission webhook servers running on nodes)
resource "aws_vpc_security_group_egress_rule" "cluster_egress_to_nodes_webhooks" {
  description                  = "Allow control plane to reach webhook servers on nodes"
  security_group_id            = aws_security_group.eks_cluster.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
}

# --- Node SG rules ---

# Ingress: control plane → nodes (kubelet API)
resource "aws_vpc_security_group_ingress_rule" "nodes_ingress_from_cluster_kubelet" {
  description                  = "Allow control plane to reach kubelet"
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_cluster.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}

# Ingress: control plane → nodes (admission webhooks)
resource "aws_vpc_security_group_ingress_rule" "nodes_ingress_from_cluster_webhooks" {
  description                  = "Allow control plane to reach webhook servers"
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_cluster.id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
}

# Ingress: node → node (pod-to-pod traffic via VPC CNI)
# All protocols and ports are permitted between nodes — this is required for VPC CNI
# pod networking. Security groups operate at the node level and cannot distinguish
# between pods on the same node. Workload-level isolation must be enforced via
# Kubernetes NetworkPolicy, not security groups.
resource "aws_vpc_security_group_ingress_rule" "nodes_ingress_from_nodes" {
  description                  = "Allow all node-to-node traffic for pod networking"
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  ip_protocol                  = "-1"
}

# Egress: node → node (pod-to-pod traffic via VPC CNI)
# See ingress rule above for rationale.
resource "aws_vpc_security_group_egress_rule" "nodes_egress_to_nodes" {
  description                  = "Allow all node-to-node traffic for pod networking"
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  ip_protocol                  = "-1"
}

# Egress: nodes → control plane (API server)
resource "aws_vpc_security_group_egress_rule" "nodes_egress_to_cluster" {
  description                  = "Allow nodes to reach the API server"
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_cluster.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# Egress: nodes → internet (image pulls from ECR/DockerHub, AWS APIs via NAT)
resource "aws_vpc_security_group_egress_rule" "nodes_egress_to_internet" {
  description       = "Allow nodes to reach container registries and AWS APIs"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Egress: nodes → DNS (UDP and TCP)
# Required for cert-manager DNS-01 propagation checks which query authoritative
# nameservers directly on port 53. UDP is standard DNS; TCP is used for large responses.
resource "aws_vpc_security_group_egress_rule" "nodes_egress_dns_udp" {
  description       = "Allow nodes to make DNS queries (UDP)"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "nodes_egress_dns_tcp" {
  description       = "Allow nodes to make DNS queries (TCP)"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}

# 3. KMS Key for Envelope Encryption

resource "aws_kms_key" "eks_secrets" {
  description             = "EKS KMS Master Key for Secret Encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "eks_secrets" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# 4. Control Plane Logs

# Manage the log group explicitly so a retention policy can be applied.
# EKS creates this group automatically if it doesn't exist, but without
# Terraform ownership there is no way to set retention and logs accumulate indefinitely.
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
}

# 5. The EKS Cluster

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.cluster_access_mode == "public"
    public_access_cidrs     = var.cluster_access_mode == "public" ? var.public_access_cidrs : null
  }

  # Hardened auditing to CloudWatch Logs
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  # Native EKS Access Entries Mode (Modern replacement for configmaps)
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.eks,
  ]
}

# Explicit cluster admin access entries — one per IAM role ARN provided.
# bootstrap_cluster_creator_admin_permissions is false so all access is managed here.
resource "aws_eks_access_entry" "cluster_admins" {
  for_each      = toset(var.cluster_admin_role_arns)
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admins" {
  for_each      = toset(var.cluster_admin_role_arns)
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# 6. Explicitly Configured Managed Node Groups

resource "aws_launch_template" "nodes" {
  for_each = var.node_groups
  name     = each.value.name

  # Attach the custom node security group. EKS adds its own cluster-managed
  # security group alongside this one automatically.
  vpc_security_group_ids = [aws_security_group.eks_nodes.id]

  # Require IMDSv2. Hop limit of 1 restricts IMDS access to the node itself —
  # pods should obtain IAM credentials via EKS Pod Identity or IRSA rather
  # than inheriting the node's IAM role through IMDS.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

resource "aws_eks_node_group" "workers" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.value.name
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = each.value.subnet_ids

  ami_type       = each.value.ami_type
  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type

  launch_template {
    id      = aws_launch_template.nodes[each.key].id
    version = aws_launch_template.nodes[each.key].latest_version
  }

  scaling_config {
    desired_size = each.value.min_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable = each.value.max_unavailable
  }

  labels = each.value.labels

  # Ignore desired_size after initial creation so the Cluster Autoscaler can
  # scale the node group without Terraform resetting it on the next apply.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  # Ensure IAM roles are bound before nodes attempt to join and fail provisioning.
  depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# 7. Core Add-ons

# Provides DNS resolution for pods and services within the cluster. Without
# CoreDNS, pods cannot resolve Kubernetes service names.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  addon_version               = var.addon_versions.coredns
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.workers]
}

# Manages iptables rules on each node to implement Kubernetes Service routing
# (ClusterIP, NodePort). EKS installs kube-proxy automatically but managing it
# as an addon gives explicit version control and enables Terraform-driven upgrades.
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  addon_version               = var.addon_versions.kube_proxy
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.workers]
}

# Assigns VPC IP addresses directly to pods. Required for pod networking on EKS.
# Prefix delegation is enabled to allocate /28 prefixes per node rather than
# individual IPs, avoiding exhaustion in production subnets.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = var.addon_versions.vpc_cni
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  depends_on = [aws_eks_node_group.workers]
}

# Required when using EKS Pod Identity for pod IAM credentials. Omit
# pod_identity_agent from addon_versions if using IRSA instead.
resource "aws_eks_addon" "pod_identity_agent" {
  count = var.addon_versions.pod_identity_agent != null ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = var.addon_versions.pod_identity_agent
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.workers]
}
