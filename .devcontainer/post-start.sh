#!/usr/bin/env bash
# Runs every time the Codespace starts. Docker-in-docker isn't available during
# prebuilds, so images are pulled here.
set -uo pipefail

for i in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
./scripts/check-env.sh
