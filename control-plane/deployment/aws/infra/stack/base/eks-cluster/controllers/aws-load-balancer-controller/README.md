# base/eks-cluster/controllers/aws-load-balancer-controller

Terragrunt unit that creates the IAM role and EKS Pod Identity Association for the AWS Load Balancer Controller. The controller itself is deployed separately — see [`k8s/controllers/`](../../../../../../../../../k8s/controllers/README.md).

The IAM role grants the controller permission to create and manage AWS Network Load Balancers and Application Load Balancers in response to Kubernetes Service and Ingress resources.

## Configuration

All fields are optional. The unit reads the cluster name from `base/eks-cluster/cluster` automatically.

To switch from EKS Pod Identity (default) to IRSA, or to override the cluster name or IAM resource names, copy `common.local.hcl.example` to `common.local.hcl` and uncomment the relevant fields.
