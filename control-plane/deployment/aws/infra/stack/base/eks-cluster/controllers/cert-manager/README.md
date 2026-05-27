# base/eks-cluster/controllers/cert-manager

Terragrunt unit that creates the IAM role and EKS Pod Identity Association for cert-manager. cert-manager is deployed separately — see [`k8s/controllers/`](../../../../../../../../../k8s/controllers/README.md).

The IAM role grants cert-manager permission to create and delete Route53 DNS records in the hosted zone, which it uses for DNS01 ACME challenges when issuing certificates.

## Configuration

All fields are optional. The unit reads the cluster name from `base/eks-cluster/cluster` and the Route53 zone ID from `base/dns` automatically.

To switch from EKS Pod Identity (default) to IRSA, or to override the cluster name, zone ID, or IAM resource names, copy `common.local.hcl.example` to `common.local.hcl` and uncomment the relevant fields.
