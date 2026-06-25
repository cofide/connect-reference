# eks-cluster/cluster

Terragrunt unit that provisions the EKS cluster for the Connect control plane. Creates:

- EKS control plane with managed add-ons (CoreDNS, kube-proxy, VPC CNI, EKS Pod Identity Agent)
- Managed node group in private subnets
- KMS key for EKS secret encryption
- IAM roles for the cluster and node group
- Security groups for cluster and node communication
- EKS access entries granting cluster-admin to the configured IAM role ARNs
- OIDC provider (required for IRSA; optional when using Pod Identity)

The `base/database/rds-instance/` and `base/eks-cluster/controllers/*` units all depend on this unit.

## Configuration

Copy `common.local.hcl.example` to `common.local.hcl`. At minimum, set `cluster_admin_role_arns` to include the IAM role ARN you use to access AWS:

```hcl
locals {
  cluster_admin_role_arns = [
    "arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/eu-west-1/AWSReservedSSO_AdministratorAccess_abc123",
  ]
}
```

Find your current role ARN with:

```sh
aws sts get-caller-identity --query Arn --output text
```

If using an assumed-role, then get the permanent IAM role with:

```sh
aws iam list-roles
```

and extract the role ARN.

## Cluster Access

The cluster is deployed with `cluster_access_mode` controlling how the EKS API server is reached. Set this in `common.local.hcl` before applying.

### SSM mode (default)

The API server has no public endpoint. Access from developer machines is via SSM port forwarding through a private EC2 jump instance — no public IPs, no open inbound ports, no SSH keys.

#### Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with credentials for the target account
- [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI
- `kubectl`
- Your IAM role ARN must be present in `cluster_admin_role_arns` in the Terragrunt config

#### One-time kubeconfig setup

Retrieve the Terraform outputs:

```sh
CLUSTER_NAME=$(terragrunt output -raw cluster_name)
CLUSTER_HOST=$(terragrunt output -raw cluster_endpoint_hostname)
JUMP_INSTANCE_ID=$(cd ../../jump && terragrunt output -raw instance_id)
```

Generate the kubeconfig and redirect kubectl to the local tunnel port:

```sh
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region <region>

kubectl config set-cluster "$(kubectl config current-context)" \
  --server=https://127.0.0.1:6443 \
  --tls-server-name="$CLUSTER_HOST"
```

The `--tls-server-name` flag preserves full TLS verification against the real EKS certificate — no need to skip TLS.

#### Accessing the cluster

Each session requires an active SSM tunnel. Open a dedicated terminal and run:

```sh
aws ssm start-session \
  --target "$JUMP_INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$CLUSTER_HOST\"],\"portNumber\":[\"443\"],\"localPortNumber\":[\"6443\"]}" \
  --region <region>
```

Leave this running. In any other terminal, kubectl commands work normally:

```sh
kubectl get nodes
```

Close the tunnel terminal when done.

### Public mode

Set `cluster_access_mode = "public"` in `common.local.hcl` to expose the API server endpoint publicly. The SSM jump instance is not required in this mode.

`public_access_cidrs` can be used to restrict access to known source CIDRs (e.g. a corporate egress IP). It defaults to `["0.0.0.0/0"]` (unrestricted) if not set.

#### One-time kubeconfig setup

```sh
CLUSTER_NAME=$(terragrunt output -raw cluster_name)

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region <region>
```

kubectl commands work immediately with no tunnel required.
