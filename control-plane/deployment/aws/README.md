# Connect Control Plane — AWS Reference Deployment

This directory contains a reference deployment of the [Cofide Connect](https://docs.cofide.dev) control plane on AWS. It provisions all infrastructure needed to run the Connect API and UI, backed by a SPIRE server for workload identity of control plane components.

## Architecture

```
                          Internet
                        ┌────┴────────────────────────────────────┐
                        │                                         │
                        ▼                                         ▼
┌─ VPC ─────────────────────────────────────────┐            CloudFront
│                                               │                 │
│ ┌──── Public subnets ───────────────────────┐ │          origin │
│ │     NLBs                                  │ │                 ▼
│ │     (Connect API · SPIRE OIDC Discovery   │ │   S3  (trust bundle bucket)
│ │      · Connect UI)                        │ │                 ▲
│ └──────────────┬────────────────────────────┘ │          writes │
│                 │                             │                 │
│ ┌──── Private subnets ──────────────────────┐ │                 │
│ │     EKS Cluster                           │ │                 │
│ │ ┌──── SPIRE Server + OIDC Discovery       │ │                 │
│ │ ├──── Connect API ────────────────────────┼─┼─────────────────┘
│ │ │     Connect UI                          │ │
│ │ │     cert-manager · ExternalDNS          │ │
│ │ │     AWS Load Balancer Controller        │ │
│ └─┼─────────────────────────────────────────┘ │
│   │                                           │
│ ┌─┼── Intra subnets ────────────────────────┐ │
│ │ └─▶ RDS PostgreSQL                        │ │
│ └───────────────────────────────────────────┘ │
└───────────────────────────────────────────────┘

Route53 manages DNS records for the NLBs and CloudFront distribution.
```

The deployment interleaves infrastructure (`infra/stack/`) and Kubernetes (`k8s/`) steps:

1. Base AWS infrastructure (VPC, EKS cluster, RDS) — Terraform
2. SPIRE server AWS resources and PostgreSQL database and role — Terraform
3. Kubernetes controllers (cert-manager, ExternalDNS, AWS Load Balancer Controller) — Helm and Kustomize
4. SPIRE server — Helm
5. Connect AWS resources, PostgreSQL database and role — Terraform (requires the SPIRE OIDC endpoint to be live, as the Connect IAM role registers it as an AWS identity provider at apply time)
6. Connect API and Connect UI — Helm and Kustomize

## Design decisions

This reference makes specific choices for each component of the deployment. Understanding these choices makes it easier to adapt the deployment to your own requirements.

### Compute: EKS

The Connect API, Connect UI, and SPIRE server run on an EKS cluster in private subnets. NLBs in public subnets provide internet-facing ingress.

### SPIRE server key manager: AWS KMS

Each SPIRE server replica creates and manages its own KMS key, identified by the pod name via the Kubernetes Downward API. This lets the SPIRE server run as a `Deployment` — replicas are stateless and can be rescheduled freely without needing persistent volumes or coordinating key access. A `StatefulSet` with persistent storage is an alternative.

### SPIRE server upstream authority: cert-manager

cert-manager issues the upstream CA certificate that SPIRE uses to sign workload SVIDs. It needs no external PKI infrastructure. [AWS Private CA](https://aws.amazon.com/private-ca/) is an alternative for a fully AWS-native setup, though it costs ~$400/month.

### SPIRE server datastore: RDS PostgreSQL

Both the SPIRE server and the Connect API use PostgreSQL on RDS. This reference provisions a single shared RDS instance — a deployment choice. They can run on separate instances if isolation is preferred.

### Trust bundle storage: S3

The Connect API writes SPIFFE trust bundles to a KMS-encrypted S3 bucket. The bucket must be accessible via a stable HTTPS URL reachable by the Cofide SPIRE servers managing Connect trust zones.

### Trust bundle exposure: CloudFront

A CloudFront distribution in front of the S3 bucket serves the bundles. Any CDN or reverse proxy that provides a stable HTTPS URL works — see [`infra/stack/connect/README.md`](infra/stack/connect/README.md) for details on skipping CloudFront.

### Ingress: ExternalDNS, AWS Load Balancer Controller, cert-manager

These three controllers manage DNS records, NLBs, and TLS certificates. Any tooling that produces valid TLS certificates and L4 load balancers will work in their place. TLS termination happens inside the pod via the envoy sidecar, so the load balancers must operate at L4 — L7 load balancers that terminate TLS before the pod won't work.

## Prerequisites

| Tool | Notes |
|------|-------|
| [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | AWS API access and SSM tunnels |
| [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) | SSM port forwarding to RDS and EKS |
| [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.10 | Infrastructure provisioning (S3 native lock file backend requires 1.10) |
| [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) ≥ 0.55 | Stack orchestration (used by this reference; optional if driving Terraform directly) |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes access |
| [Helm](https://helm.sh/docs/intro/install/) ≥ 3 | Chart installation |
| [yq](https://github.com/mikefarah/yq) v4 | YAML parsing in install scripts |
| [jq](https://jqlang.github.io/jq/) | JSON parsing |
| [psql](https://www.postgresql.org/docs/current/app-psql.html) | Database access during setup |

Your AWS IAM identity needs permissions to create and manage VPC, EKS, RDS, IAM, S3, CloudFront, KMS, Route53, and SSM resources.

## Deployment

The deployment interleaves Terraform and Kubernetes steps. `connect/iam-role` registers the SPIRE OIDC endpoint as an AWS identity provider — the endpoint must be live before that unit can be applied.

### Existing infrastructure

If you already have a VPC, EKS cluster, RDS PostgreSQL instance, and DNS zone, the core deployment is four steps:

1. **[SPIRE infrastructure](infra/stack/spire-server/README.md)** — SPIRE server IAM role, PostgreSQL database and role (`infra/stack/spire-server/`)
2. **[SPIRE server](k8s/spire-server/README.md)** — SPIRE CRDs and SPIRE server Helm releases (`k8s/spire-server/`)
3. **[Connect infrastructure](infra/stack/connect/README.md)** — S3, CloudFront, Connect IAM role, PostgreSQL database and role (`infra/stack/connect/`)
4. **[Connect API and Connect UI](k8s/connect/README.md)** — Connect API and Connect UI Helm releases and certificates (`k8s/connect/`)

Once all four steps are complete, run `print-cofidectl-config.sh` to print the `cofidectl connect init` command with all values filled in:

```sh
./print-cofidectl-config.sh
```

then run the printed command to initialise your local cofidectl.

cert-manager (with a Route53 DNS01 ClusterIssuer), ExternalDNS, and the AWS Load Balancer Controller must be running on the cluster before step 2. If not already installed, deploy them first — see [`k8s/controllers/README.md`](k8s/controllers/README.md).

Each Terraform unit reads resource IDs from other units in the stack by default. Supply your existing resource IDs in each unit's `common.local.hcl` — see [`infra/stack/README.md`](infra/stack/README.md) for the values to set.

### From scratch

To provision the full reference stack from scratch, add these two steps before the above:

1. **[Base infrastructure](infra/stack/README.md#reference-base-infrastructure)** — VPC, DNS, EKS cluster, RDS (`infra/stack/base/`)
2. **[Kubernetes controllers](k8s/controllers/README.md)** — cert-manager, ExternalDNS, AWS Load Balancer Controller (`k8s/controllers/`)

## Production hardening

This reference deployment is designed to be easy to bring up and tear down. Before using it as the basis for a production deployment, consider the following additions:

- **VPC flow logs** — enable `aws_flow_log` on the VPC, logging to CloudWatch Logs or S3 with a retention policy. Flow logs are the primary means of detecting unexpected lateral movement within the VPC.
- **CloudTrail** — enable a multi-region trail with S3 log delivery, log file validation, and data events on the trust bundle S3 bucket. CloudTrail records IAM `AssumeRole` events, KMS key usage, and S3 bucket policy changes that are otherwise invisible.
- **RDS deletion protection and final snapshot** — set `deletion_protection = true`, `skip_final_snapshot = false`, and provide a `final_snapshot_identifier` in `common.local.hcl`. The defaults are intentionally permissive to allow clean teardown of the reference deployment.
- **RDS backup retention** — increase `backup_retention_period` to at least 7 days (14–30 advisable).
- **RDS log exports and enhanced monitoring** — set `enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]` and `monitoring_interval = 60` to ship authentication failures and slow queries to CloudWatch.
- **EKS control plane log retention** — increase the CloudWatch log group retention period from the default 7 days to at least 90 days for security investigation purposes.
- **Stateful resource protection** — add `prevent_destroy = true` lifecycle rules to the RDS instance, KMS keys, and trust bundle S3 bucket to guard against accidental deletion.

## Teardown

To delete a Connect deployment deployed using this reference stack, perform the following actions in order:

1. Uninstall the Connect API and UI Helm charts: `helm uninstall -n connect connect connect-ui`. ExternalDNS controller will delete the corresponding Route53 DNS records and AWS Loadbalancer Controller will delete the corresponding network loadbalancers.
2. Manually delete the contents of the Connect Bundle S3 bucket (or set `force_destroy = true` in the bundle-bucket [config](./infra/stack/connect/bundle-bucket/common.local.hcl) then run `terragrunt apply && terragrunt destroy` from the `bundle-bucket` directory). This is required because non-empty S3 buckets cannot be deleted by default.
3. Tear down the Connect Terragrunt stack from the [infra/stack/connect](./infra/stack/connect) directory with `terragrunt run --all --no-auto-approve --filter '!name=database' destroy` (skipping the database unit since the full RDS instance will be deleted later anyway).
4. Uninstall the SPIRE Helm chart: `helm uninstall -n spire-mgmt spire spire-crds`. ExternalDNS controller should delete the corresponding Route53 DNS records for the OIDC discovery provider.
5. Tear down the SPIRE IAM role unit by running `terragrunt destroy` from the [infra/stack/spire-server/iam-role](./infra/stack/spire-server/iam-role) directory.
6. Remove all base infrastructure by running `terragrunt run --all --no-auto-approve --filter '!name=iam-admin' destroy` from the [infra/stack/base](./infra/stack/base) directory.
