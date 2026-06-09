# Kubernetes Controllers

cert-manager, ExternalDNS, and the AWS Load Balancer Controller are required by the Connect control plane.

**If these controllers are already installed on your cluster**, skip to [ClusterIssuer](#clusterissuer) — you still need a cert-manager ClusterIssuer configured for Route53 DNS01 challenges even if cert-manager itself is already running.

The ClusterIssuer uses Route53 DNS01 challenges. cert-manager needs an IAM role with `route53:ChangeResourceRecordSets` permission on your hosted zone to complete them. If that role does not already exist, apply the cert-manager controller unit before installing the ClusterIssuer — even if cert-manager itself is already installed:

```sh
cd infra/stack/base/eks-cluster/controllers/cert-manager
cp common.local.hcl.example common.local.hcl
# Set cluster_name and zone_id (the Route53 hosted zone ID).
terragrunt apply
```

## cert-manager

SPIRE uses cert-manager as its upstream CA authority. Install it first.

```sh
cd controllers/cert-manager
./install.sh
```

After cert-manager is running, apply the ClusterIssuer.

### ClusterIssuer

The ClusterIssuer uses Route53 DNS01 challenges to issue TLS certificates for the SPIRE OIDC endpoint, Connect API, and Connect UI.

```sh
cd controllers/cert-manager/cluster-issuer

# If the infra stacks were used, generate from Terragrunt outputs:
./generate-cluster-issuer-local.sh admin@example.com

# Otherwise, copy the example and fill in your values:
cp cluster-issuer.local.yaml.example cluster-issuer.local.yaml

./apply.sh
```

## ExternalDNS

```sh
cd controllers/external-dns

# From Terragrunt outputs:
./generate-local-values.sh

# Or manually:
cp values.local.yaml.example values.local.yaml

./install.sh
```

## AWS Load Balancer Controller

```sh
cd controllers/aws-load-balancer-controller

# From Terragrunt outputs:
./generate-local-values.sh

# Or manually:
cp values.local.yaml.example values.local.yaml

./install.sh
```
