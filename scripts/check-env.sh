#!/usr/bin/env bash
# Checks the tools the labs need and pre-pulls the images render uses, so the
# session doesn't depend on conference Wi-Fi.
#
#   ./scripts/check-env.sh            # check and pre-pull
#   ./scripts/check-env.sh --no-pull  # check only
set -uo pipefail

CROSSPLANE_VERSION=v2.4.2
IMAGES=(
  "xpkg.crossplane.io/crossplane/crossplane:${CROSSPLANE_VERSION}"
  "xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.11.1"
  "xpkg.crossplane.io/crossplane-contrib/function-auto-ready:v0.7.1"
)
REF=https://github.com/upbound/function-lifecycle

ok=1
pass() { printf '  \033[32m✔\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✘\033[0m %s\n' "$1"; ok=0; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

echo "Required"
if command -v go >/dev/null; then
  v=$(go env GOVERSION | sed 's/^go//')
  if [ "$(printf '%s\n1.26\n' "$v" | sort -V | head -1)" = "1.26" ]; then pass "go $v"; else fail "go $v (need 1.26+)"; fi
else fail "go (need 1.26+): https://go.dev/dl"; fi

if command -v crossplane >/dev/null; then
  pass "crossplane $(crossplane version --client 2>/dev/null | awk '{print $NF}')"
  crossplane composition render --help >/dev/null 2>&1 || fail "crossplane CLI is too old (need v2.5+): curl -sfL https://cli.crossplane.io/install.sh | sh"
else fail "crossplane CLI: curl -sfL https://cli.crossplane.io/install.sh | sh"; fi

if docker info >/dev/null 2>&1; then pass "docker $(docker version --format '{{.Server.Version}}')"; else fail "docker daemon not reachable"; fi
if command -v git >/dev/null; then pass "git $(git --version | awk '{print $3}')"; else fail "git"; fi

echo "Lab 5 (PR-ready)"
if command -v golangci-lint >/dev/null; then pass "golangci-lint $(golangci-lint version --short 2>/dev/null)"
else warn "golangci-lint missing: go run github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.12.0 run ./... works too"; fi
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then pass "gh (logged in)"; else warn "gh missing or not logged in: you can open the PR in the browser instead"; fi

echo "Lab 6 (take-home cluster)"
for t in kind kubectl helm; do
  if command -v "$t" >/dev/null; then pass "$t"; else warn "$t missing (only needed for Lab 6)"; fi
done

if [ "${1:-}" != "--no-pull" ] && docker info >/dev/null 2>&1; then
  echo "Pre-pulling images"
  for i in "${IMAGES[@]}"; do
    if docker pull -q "$i" >/dev/null; then pass "$i"; else fail "$i"; fi
  done
  echo "Warming the Go module cache"
  tmp=$(mktemp -d)
  if git clone -q --depth 1 "$REF" "$tmp/fn" 2>/dev/null && (cd "$tmp/fn" && go mod download && go build ./... && go test ./... >/dev/null); then
    pass "function-lifecycle modules"
  else
    warn "couldn't warm the cache from $REF (fine if the repo isn't public yet)"
  fi
  rm -rf "$tmp"
fi

echo
if [ $ok -eq 1 ]; then echo "You're ready for the labs."; else echo "Fix the ✘ items above, or use the Codespace."; exit 1; fi
