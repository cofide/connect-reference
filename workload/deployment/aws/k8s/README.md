# Trust Zone Kubernetes

Helm and Kustomize deployment of the Kubernetes workloads for a Cofide Connect trust zone. The AWS resources in `infra/stack/` must be applied before starting here — see [`infra/stack/README.md`](../infra/stack/README.md).

## Prerequisites

- `kubectl` configured to talk to the trust zone EKS cluster. See [`infra/stack/eks-cluster/cluster/README.md`](../infra/stack/eks-cluster/cluster/README.md) for kubeconfig setup.
- The SPIRE AWS resources in `infra/stack/spire-server/` must be applied before deploying the SPIRE server.
- `helm`, `yq`, and `kubectl` installed.

---

## cert-manager

cert-manager is used as the upstream CA authority for the SPIRE server. It does not require AWS credentials in this configuration — the ClusterIssuer uses a self-signed certificate rather than ACME DNS-01 challenges.

```sh
cd cert-manager
./install.sh

cd cluster-issuer
./apply.sh
```

The ClusterIssuer is named `selfsigned` and is referenced by the SPIRE server's upstream authority configuration.

---

## SPIRE server

Deploy the SPIRE server. cert-manager must be running and the `selfsigned` ClusterIssuer must be applied before installing the SPIRE chart.

Generate `values.local.yaml` from the Terragrunt outputs and your chosen parameters:

```sh
cd spire-server/spire
./generate-local-values.sh <ca-country> <ca-organization> <ca-common-name>
```

Where:
- `ca-country` — two-letter country code for the upstream CA subject
- `ca-organization` — organisation name for the upstream CA subject
- `ca-common-name` — common name for the upstream CA subject

All values are derived automatically from the Terragrunt stack outputs and deployed Helm releases. The following must be in place before running this script:

- The AWS infrastructure units (`eks-cluster/cluster`, `spire-server/iam-role`) must be applied.
- The `connect/trust-zone` unit must be applied — see [`infra/stack/connect/README.md`](../infra/stack/connect/README.md).
- `COFIDE_API_TOKEN` must be set.
- `kubectl` must be configured for the control-plane cluster (to read `connectPSATAudience` from the `connect-api` Helm release).

Alternatively, copy `values.local.yaml.example` to `values.local.yaml` and fill in the values manually.

Then install:

```sh
./install.sh
```

The SPIRE server uses Connect as its datastore and AWS KMS for key management. The OIDC discovery provider is deployed as a cluster-internal `ClusterIP` service. If external JWT validation is required, change `spiffe-oidc-discovery-provider.service.type` to `LoadBalancer` in `values.yaml` and add an external-dns hostname annotation in `values.local.yaml`.
