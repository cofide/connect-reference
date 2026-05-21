#!/usr/bin/env bash

# This script waits for the given federation to become healthy in Connect.

set -euxo pipefail

trust_zone_1_name="$1"
trust_zone_2_name="$2"

## Wait for federation to be established
for i in {1..24}; do
  if [ "$(cofidectl federation list | awk -F '|' '{ gsub(/ /,""); print $1":"$2":"$3 }' | grep "$trust_zone_1_name:$trust_zone_2_name:Healthy")" != "" ]; then
    echo "Federation healthy"
    exit 0
  fi
  echo "Waiting for federation from $trust_zone_1_name to $trust_zone_2_name..."
  sleep 5
done

echo "Federation from $trust_zone_1_name to $trust_zone_2_name not healthy after 2 minutes"
exit 1
