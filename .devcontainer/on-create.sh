#!/usr/bin/env bash
# Runs once when the container is created, and during Codespaces prebuilds. Put
# anything slow here so attendees don't wait for it.
set -euo pipefail

CROSSPLANE_CLI_VERSION=v2.5.0
GOLANGCI_VERSION=v2.12.0
KIND_VERSION=v0.33.0

cd /tmp
curl -sfL https://cli.crossplane.io/install.sh | XP_VERSION="$CROSSPLANE_CLI_VERSION" sh
sudo install -m 0755 crossplane /usr/local/bin/crossplane && rm crossplane

curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh | sudo sh -s -- -b /usr/local/bin "$GOLANGCI_VERSION"

curl -sfLo kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-$(dpkg --print-architecture)"
sudo install -m 0755 kind /usr/local/bin/kind && rm kind

# Warm the Go module and build caches, including controller-gen for go generate.
tmp=$(mktemp -d)
crossplane xpkg init warmup function-template-go -d "$tmp/warmup" -r >/dev/null
(cd "$tmp/warmup" && go mod download && go build ./... && go test ./... >/dev/null && go generate ./...)
if git clone -q --depth 1 https://github.com/upbound/function-lifecycle "$tmp/fn"; then
  (cd "$tmp/fn" && go mod download && go test ./... >/dev/null)
fi
rm -rf "$tmp"
