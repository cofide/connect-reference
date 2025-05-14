#!/bin/bash

# This script performs prerequisites necessary for using Connect and cofidectl.

set -euxo pipefail

if ! type cofidectl; then
  echo "Unable to find cofidectl"
  exit 1
fi

if ! cofidectl connect login --check; then
  cofidectl connect login
fi

if ! aws sts get-caller-identity; then
  aws sso login
fi

aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 010438484483.dkr.ecr.eu-west-1.amazonaws.com
aws ecr get-login-password --region eu-west-1 | helm registry login --username AWS --password-stdin 010438484483.dkr.ecr.eu-west-1.amazonaws.com
