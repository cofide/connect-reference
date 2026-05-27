# Control Plane Kubernetes

Helm and Kustomize deployment of the Kubernetes workloads for the Connect control plane. The SPIRE AWS resources must be applied before starting here, and the Connect AWS resources must be applied between the SPIRE and Connect sections — see [`infra/stack/README.md`](../infra/stack/README.md).

## Prerequisites

- `kubectl` configured to talk to the EKS cluster. See [`infra/stack/base/eks-cluster/cluster/README.md`](../infra/stack/base/eks-cluster/cluster/README.md) for kubeconfig setup (from-scratch deployments) or use `aws eks update-kubeconfig` for an existing cluster.
- The SPIRE AWS resources in `infra/stack/spire-server/` must be applied before deploying the SPIRE server.
- cert-manager, ExternalDNS, and the AWS Load Balancer Controller must be running on the cluster. If not already installed, see [`controllers/README.md`](controllers/README.md).

---

## SPIRE server

Deploy the SPIRE CRDs and SPIRE server. See [`spire-server/README.md`](spire-server/README.md) for the full steps.

After the SPIRE OIDC discovery endpoint is publicly reachable, return to [`infra/stack/README.md`](../infra/stack/README.md) and apply the Connect infrastructure before continuing.

---

## Connect

Deploy the Connect API and Connect UI. See [`connect/README.md`](connect/README.md) for the full steps.

---

## Controllers

cert-manager, ExternalDNS, and the AWS Load Balancer Controller handle certificate management, DNS, and ingress in this reference. Any tooling that produces valid TLS certificates and L4 load balancers will work — see [design decisions](../README.md#design-decisions) in the top-level README.

**If these controllers are already running on your cluster with appropriate IAM access to Route53 and your EKS cluster, skip this section.** You will need a cert-manager ClusterIssuer configured for Route53 DNS01 challenges — see [`controllers/README.md`](controllers/README.md) for how to apply one.

If you need to install the controllers from scratch, see [`controllers/README.md`](controllers/README.md).
