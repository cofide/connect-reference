#!/bin/bash

set -euxo pipefail

curl -sfL https://get.cofide.dev/cofidectl.sh --output cofidectl.sh
bash cofidectl.sh
