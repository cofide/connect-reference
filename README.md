# Connect Reference

This repository contains scripts and configuration to create reference deployments of Connect workload clusters.

## Access requirements

In order to run these reference deployments, you will need the following information:

- Access to a Cofide Connect API
  - Connect API URL
  - Connect trust domain
  - Connect bundle host
- Connect API login
  - OIDC authorization domain and client ID
- AWS credentials
  - Authorized for access to Cofide Elastic Container Registry (ECR) repositories

The scripts use the [aws](https://aws.amazon.com/cli/) CLI to obtain credentials for Docker and Helm to access ECR.

## Software Requirements

You will also need the following software installed on the machine running the deployments:

- [aws CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
- [curl](https://curl.se/)
- [docker](https://docs.docker.com/engine/install/)
- [Helm](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [uuidgen](https://man7.org/linux/man-pages/man1/uuidgen.1.html)
- [yq](https://mikefarah.gitbook.io/yq/)

If running the local Kind-based deployments you will also need:

- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)

## Configuration

Create a `config.env` file from the example:
```sh
cp config.env.example config.env
```

Edit `config.env` to populate the variables for your Connect API.

### EKS

NOTE: The provided Terraform configuration for creating an EKS cluster uses a module that is currently private to Cofide. It is possible to use an existing EKS cluster.

Skip this section if not running scripts that execute against AWS EKS.

Create a `terraform.tfvars` file from the example:
```sh
cp terraform/eks-clusters/terraform.tfvars.example terraform/eks-clusters/terraform.tfvars
```

Edit `terraform/eks-clusters/terraform.tfvars` to populate the variables for your EKS cluster.

Create an `eks.env` file from the example:
```sh
cp eks.env.example eks.env
```

Edit `eks.env` to populate the variables for your EKS cluster.

## Download cofidectl and Connect plugin

Run this script to download cofidectl and the Connect plugin:
```sh
./get-cofidectl.sh
```

## Prerequisites

Run this script before any others to perform checks and logins:
```sh
./prerequisites.sh
```

## Single trust zone with cofidectl

Run this script to deploy a single trust zone in a Kind cluster using cofidectl.
Validates the deployment with ping-pong.

```sh
./single-trust-zone-cofidectl.sh
```

A corresponding script that uses cofidectl and [terraform-provider-cofide](https://registry.terraform.io/providers/cofide/cofide/latest/docs) can be run using:

```sh
./single-trust-zone-cofidectl-tf.sh
```

## Federated trust zones with cofidectl

Run this script to deploy two federated trust zones in Kind clusters using cofidectl.
Validates the deployment with federated ping-pong.

```sh
./federated-cofidectl.sh
```

A corresponding script that uses cofidectl and [terraform-provider-cofide](https://registry.terraform.io/providers/cofide/cofide/latest/docs), with the Cofide trust zone server can be run using:

```sh
./federated-cofidectl-tf.sh
```

## Multi-mesh with cofidectl

Run this script to deploy two federated trust zones in Kind clusters with Istio using cofidectl.
An Istio gateway and a Cofide Federated Service are created in one of the clusters.
Validates the deployment with multi-mesh ping-pong.

```sh
./multi-mesh-cofidectl.sh
```

## Single trust zone with cofidectl on EKS

This script requires an AWS EKS cluster.
Use your own EKS cluster or use the Terraform configration in `terraform/eks-clusters` to provision one.

Run this script to deploy a single trust zone in an existing AWS EKS cluster using cofidectl.
Validates the deployment with ping-pong.

```sh
./single-trust-zone-cofidectl-eks.sh
```

## Federated trust zones with Helm on EKS

This script requires two AWS EKS clusters.
Use your own EKS clusters or use the Terraform configration in `terraform/eks-clusters` to provision them.

Run this script to deploy two federated trust zones in existing AWS EKS clusters using cofidectl to generate Helm values with the Cofide Terraform provider and Cofide Trust Zone Server.
Validates the deployment with ping-pong.

```sh
./federated-helm-tf-eks.sh
```
