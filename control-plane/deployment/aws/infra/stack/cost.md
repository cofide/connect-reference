# AWS Infrastructure Cost Reference

Estimated monthly costs for the Connect control plane reference deployment using current default values. Figures are for a deployment to eu-west-2 using on-demand pricing. This is provided as a guide - refer to AWS documentation for up-to-date resource pricing.

## Billable Resources

### EKS Cluster

- 1 EKS control plane (v1.35): ~$73/month ($0.10/hr; same in all regions)
- Node group: 2× `m7g.xlarge` (Graviton3, 4 vCPU / 16 GB, min=2 desired=2 max=3, ON_DEMAND): ~$267/month ($0.183/hr each)
- Node EBS root volumes: 2× 20 GB gp2 (EKS default): ~$5/month
- 4 add-ons (CoreDNS, kube-proxy, VPC CNI, Pod Identity Agent): no separate charge

### VPC / Networking

- 1 NAT Gateway (single AZ): ~$35/month fixed ($0.048/hr) + $0.048/GB data processed
- Internet Gateway: free
- 1 Elastic IP (attached to NAT Gateway): free while attached

### RDS PostgreSQL

- `db.t3.medium`, single-AZ, PostgreSQL 17: ~$56/month ($0.076/hr)
- 20 GB gp3 storage (autoscales to 100 GB): ~$2.55/month ($0.127/GB/month)
- 1-day backup retention: free up to DB size

### KMS Keys

- 4 static CMKs (EKS secrets, RDS storage, RDS Secrets Manager secret, bundle bucket): $4/month ($1/key/month)
- SPIRE server creates KMS keys dynamically per pod at runtime (2–3 keys, not Terraform-managed): ~$2–3/month + API call costs ($0.03/10k requests)

### EC2 Jump Instance

- `t3.micro`: ~$8.50/month ($0.0116/hr)
- SSM session charges: negligible ($0.00001/minute)

### Connect Bundle Distribution

- ACM certificate: free
- S3 bucket (bundle storage): negligible at trust bundle size (~$0.01/month)
- CloudFront distribution (PriceClass_100 — US, Canada, Europe): scales with the number of SPIRE agents fetching trust bundles
  - Data transfer out: $0.0085/GB (Europe); trust bundles are a few KB each so data costs are negligible
  - HTTPS requests: $0.0100 per 10,000 requests — the dominant cost driver
  - Each SPIRE agent fetches the bundle on its refresh interval (default every 5 minutes); 10 agents × 12/hr × 720 hr/month ≈ 86,400 requests/month ≈ $0.09/month
  - At 1,000 agents this becomes ~$8.64/month; plan accordingly if deploying at scale

### DNS and Logging

- 1 Route53 hosted zone (`control-plane-aws-reference.cofide.dev`): $0.50/month + $0.40/million queries
- CloudWatch log group (EKS control plane, 7-day retention): $0.594/GB ingested; likely negligible for control plane log volume

## Variable Costs

The following costs depend on workload and cannot be estimated upfront:

| Cost driver | Rate | Notes |
|---|---|---|
| NAT Gateway data processing | $0.048/GB | All egress from EKS nodes and jump instance (ECR pulls, SSM, API calls) |
| CloudFront requests | $0.0100/10k requests | Scales with number of SPIRE agents and bundle refresh interval |
| CloudWatch log ingestion | $0.594/GB | EKS control plane logs; low for a lightly-used cluster |
| Route53 DNS queries | $0.40/million queries | Low for internal resolution |

For a lightly-used reference deployment these are collectively likely under $5/month.

## Rough Monthly Total

| Component | Details | ~Cost/month |
|---|---|---|
| EKS control plane | v1.35 | $73 |
| 2× m7g.xlarge nodes | ON_DEMAND | $267 |
| Node EBS (2× 20 GB gp2) | EKS default | $5 |
| NAT Gateway | single-AZ | $35+ |
| RDS db.t3.medium | single-AZ, PostgreSQL 17 | $56 |
| RDS storage (20 GB gp3) | | $3 |
| KMS keys (static) | 4 keys | $4 |
| SPIRE KMS keys (runtime) | 2–3 per pod, not Terraform-managed | ~$2–3 |
| Jump t3.micro | | $9 |
| CloudFront + S3 | trust bundle distribution | ~$1 |
| Route53 + CloudWatch | | ~$1 |
| **Total** | | **~$456–457/month** |

## Optional: ACM PCA Upstream Authority

A `spire-server/upstream-authority` stack unit (ACM PCA ROOT CA in SHORT_LIVED_CERTIFICATE mode) is not included in the default stack. If added: **$50/month** per CA + $0.75/1,000 certificates issued.

## Cost Reduction Levers

- **Spot instances for EKS nodes**: 60–80% saving on compute (~$200/month saving at 2 nodes)
- **RDS reserved instance pricing**: up to 40% saving (~$22/month saving)
- **Reduce node count or instance size** if SPIRE server load is light

## Getting an Accurate Estimate

**AWS Pricing Calculator** (calculator.aws) is useful for building a BOM manually, particularly for data transfer estimates where you can supply expected GB/month.

**AWS Cost Explorer** after deployment: with resources tagged consistently (`ManagedBy=Terraform`, `Repository=github.com/cofide/connect-reference`), Cost Explorer will show actual costs per component within 24 hours of deployment.
