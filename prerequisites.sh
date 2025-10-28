#!/bin/bash

# This script performs prerequisites necessary for using Connect and cofidectl.

set -euxo pipefail

for cmd in aws cofidectl curl docker helm kubectl uuidgen; do
  if ! type $cmd; then
    echo "Unable to find $cmd"
    exit 1
  fi
done

./login.sh
