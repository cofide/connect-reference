# Connect Reference

This repository contains reference deployments for Connect workload clusters.

## Prerequisites

Run this script before any others to perform checks and logins:
```sh
./prerequisites.sh
```

## Configuration

Create a `config.env` file from the example:
```sh
cp config.env.example config.env
```

Edit `config.env` to populate the variables for your Connect API.

### EKS

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
```
./get-cofidectl.sh
```

## Single trust zone with cofidectl

Run this script to deploy a single trust zone in a Kind cluster using cofidectl.
Validates the deployment with ping-pong.

```sh
./single-trust-zone-cofidectl.sh
```

## Federated trust zones with cofidectl

Run this script to deploy two federated trust zones in Kind clusters using cofidectl.
Validates the deployment with federated ping-pong.

```sh
./federated-cofidectl.sh
```

## Multi-mesh with cofidectl

Run this script to deploy two federated trust zones in Kind clusters with Istio using cofidectl.
An Istio gateway and a Cofide Federated Service are created in one of the clusters.
Validates the deployment with multi-mesh ping-pong.

```sh
./multi-mesh-cofidectl.sh
```

## Single trust zone with cofidectl on EKS

This script requires an AWS EKS cluster. A Terraform configration is provided in `terraform/eks-clusters` that may be used to provision one.

Run this script to deploy a single trust zone in an existing AWS EKS cluster using cofidectl.
Validates the deployment with ping-pong.

```sh
./single-trust-zone-cofidectl-eks.sh
```
