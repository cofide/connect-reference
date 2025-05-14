# Connect Reference

This repository contains reference deployments for Connect workload clusters.

## Prerequisites

Run this script before any others to perform checks and logins:
```sh
./prerequisites.sh
```

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
