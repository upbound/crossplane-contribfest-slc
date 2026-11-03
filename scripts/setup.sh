#!/usr/bin/env bash
# Installs what the labs need, without Docker, and checks that it works. Run it
# before the session: the first run downloads about 250 MB, mostly Go modules,
# and then the labs work offline.
#
#   ./scripts/setup.sh           # install what's missing, warm the Go caches, smoke test
#   ./scripts/setup.sh --check   # check only, install nothing
#
# Tools go to $BIN_DIR (default ~/.local/bin). Nothing needs sudo.
set -uo pipefail

CLI_VERSION=v2.5.0          # crossplane CLI, github.com/crossplane/cli
CORE_VERSION=v2.4.3         # Crossplane itself. render runs it as the render engine.
PT_VERSION=v0.11.2          # function-patch-and-transform
GOLANGCI_VERSION=v2.12.0    # what function-template-go's CI runs
BIN_DIR=${BIN_DIR:-$HOME/.local/bin}
FN_REPO=https://github.com/upbound/function-lifecycle
SMOKE_PORT=19444

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

ok=1
if [ -t 1 ]; then g=$'\033[32m' r=$'\033[31m' y=$'\033[33m' n=$'\033[0m'; else g= r= y= n=; fi
pass() { printf '  %s✔%s %s\n' "$g" "$n" "$1"; }
fail() { printf '  %s✘%s %s\n' "$r" "$n" "$1"; ok=0; }
warn() { printf '  %s!%s %s\n' "$y" "$n" "$1"; }
step() { printf '\n%s\n' "$1"; }

# version_ge A B succeeds if version A >= B. Only compares major.minor.patch.
version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) { if (x[i]+0 > y[i]+0) exit 0; if (x[i]+0 < y[i]+0) exit 1 }
    exit 0 }'
}

sha256() { { command -v sha256sum >/dev/null && sha256sum "$1" || shasum -a 256 "$1"; } | awk '{print $1}'; }

# fetch URL FILE WANT downloads URL to FILE and checks its sha256 is WANT.
fetch() {
  curl -sfL "$1" -o "$2" || { echo "    download failed: $1"; return 1; }
  [ "$(sha256 "$2")" = "$3" ] || { echo "    checksum mismatch: $1"; return 1; }
}

listening() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  *) echo "Run this on macOS or Linux. On Windows, run it in WSL2."; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  arm64 | aarch64) arch=arm64 ;;
  *) echo "Unsupported CPU architecture: $(uname -m)"; exit 1 ;;
esac

# Resolve symlinks: crossplane xpkg init fails on paths through one, like macOS /var.
tmp=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"; [ -n "${pt_pid:-}" ] && kill "$pt_pid" 2>/dev/null' EXIT

ORIG_PATH=$PATH
case ":$PATH:" in *":$BIN_DIR:"*) path_ok=1 ;; *) path_ok=0 ;; esac
export PATH="$BIN_DIR:$PATH"

step "Required"
command -v git >/dev/null && pass "git $(git --version | awk '{print $3}')" || fail "git"
command -v curl >/dev/null && pass "curl" || fail "curl"
if command -v go >/dev/null; then
  v=$(go env GOVERSION | sed 's/^go//')
  if version_ge "$v" 1.26; then
    pass "go $v"
  elif version_ge "$v" 1.21 && [ "$(go env GOTOOLCHAIN)" != local ]; then
    warn "go $v: Go downloads 1.26 by itself the first time a module needs it"
  else
    fail "go $v: need 1.26+ from https://go.dev/dl"
  fi
else
  fail "go: install 1.26+ from https://go.dev/dl"
fi
[ $ok = 1 ] || { printf '\nInstall the ✘ tools above, then run this again.\n'; exit 1; }

step "Crossplane tools in $BIN_DIR"
mkdir -p "$BIN_DIR"

# The crossplane CLI. Any v2.5+ on your PATH will do.
cli=$(PATH=$ORIG_PATH command -v crossplane || true)
# Capture help first: grep -q exiting early can SIGPIPE the CLI, and pipefail would
# count that as a failure.
help=$([ -n "$cli" ] && "$cli" composition render --help 2>/dev/null)
if [[ $help == *--crossplane-binary* ]]; then
  pass "crossplane CLI $("$cli" version --client 2>/dev/null | awk '{print $NF}') ($cli)"
elif [ $CHECK_ONLY = 1 ]; then
  fail "crossplane CLI v2.5+: run without --check to install it"
else
  url=https://cli.crossplane.io/stable/$CLI_VERSION/bundle/${os}_${arch}/crossplane-cli.tar.gz
  if fetch "$url" "$tmp/cli.tgz" "$(curl -sfL "$url.sha256" | awk '{print $1}')" &&
    tar -xzf "$tmp/cli.tgz" -C "$tmp" crossplane && install -m 0755 "$tmp/crossplane" "$BIN_DIR/crossplane"; then
    pass "crossplane CLI $CLI_VERSION"
    [ -n "$cli" ] && warn "an older crossplane at $cli comes first on your PATH. Remove it, or put $BIN_DIR first."
  else
    fail "couldn't install the crossplane CLI"
  fi
fi

# Crossplane itself. render runs it as a local process instead of in Docker.
core=$BIN_DIR/crossplane-core
if [ "$("$core" --version 2>/dev/null)" = "$CORE_VERSION" ]; then
  pass "crossplane-core $CORE_VERSION (the render engine)"
elif [ $CHECK_ONLY = 1 ]; then
  fail "crossplane-core $CORE_VERSION: run without --check to install it"
else
  url=https://releases.crossplane.io/stable/$CORE_VERSION/bin/${os}_${arch}/crossplane
  if fetch "$url" "$tmp/core" "$(curl -sfL "$url.sha256" | awk '{print $1}')" && install -m 0755 "$tmp/core" "$core"; then
    pass "crossplane-core $CORE_VERSION (the render engine)"
  else
    fail "couldn't install crossplane-core"
  fi
fi

# The function the labs' pipeline composes resources with, run as a local process.
pt=$BIN_DIR/function-patch-and-transform
if [ "$(go version -m "$pt" 2>/dev/null | awk '$1 == "mod" {print $3}')" = "$PT_VERSION" ]; then
  pass "function-patch-and-transform $PT_VERSION"
elif [ $CHECK_ONLY = 1 ]; then
  fail "function-patch-and-transform $PT_VERSION: run without --check to install it"
else
  echo "    building function-patch-and-transform, about a minute the first time…"
  if GOBIN=$BIN_DIR go install "github.com/crossplane-contrib/function-patch-and-transform@$PT_VERSION" >"$tmp/pt.log" 2>&1; then
    pass "function-patch-and-transform $PT_VERSION"
  else
    tail -5 "$tmp/pt.log"
    fail "couldn't build function-patch-and-transform"
  fi
fi

# Lab 5 runs the same linter CI does. A golangci-lint built with an older Go
# than yours panics with "file requires newer Go version", so it must be built
# with your Go or a newer one.
go_minor=$(go env GOVERSION | sed -E 's/^go([0-9]+\.[0-9]+).*/\1/')
lint=$(PATH=$ORIG_PATH command -v golangci-lint || true)
lint_info=$([ -n "$lint" ] && "$lint" version 2>/dev/null)
lint_go=$(echo "$lint_info" | sed -nE 's/.*built with go([0-9]+\.[0-9]+).*/\1/p')
if [[ $lint_info == *"version v2."* || $lint_info == *"version 2."* ]] && [ -n "$lint_go" ] && version_ge "$lint_go" "$go_minor"; then
  pass "golangci-lint $("$lint" version --short 2>/dev/null), built with go$lint_go ($lint)"
elif [ $CHECK_ONLY = 1 ]; then
  fail "golangci-lint v2 built with go$go_minor or newer: run without --check to install it"
else
  echo "    building golangci-lint with your Go, a few minutes the first time…"
  if GOBIN=$BIN_DIR go install "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$GOLANGCI_VERSION" >"$tmp/lint.log" 2>&1; then
    pass "golangci-lint $GOLANGCI_VERSION, built with go$go_minor"
    [ -n "$lint" ] && [ "$lint" != "$BIN_DIR/golangci-lint" ] &&
      warn "the golangci-lint at $lint comes first on your PATH and was built with an older Go. Remove it, or put $BIN_DIR first."
  else
    tail -5 "$tmp/lint.log"
    fail "couldn't build golangci-lint"
  fi
fi

step "Smoke test: render without Docker"
mkdir -p "$tmp/smoke"
cat >"$tmp/smoke/xr.yaml" <<'EOF'
apiVersion: example.crossplane.io/v1
kind: Smoke
metadata:
  name: smoke
  namespace: default
EOF
cat >"$tmp/smoke/composition.yaml" <<'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: smoke
spec:
  compositeTypeRef:
    apiVersion: example.crossplane.io/v1
    kind: Smoke
  mode: Pipeline
  pipeline:
  - step: compose
    functionRef:
      name: function-patch-and-transform
    input:
      apiVersion: pt.fn.crossplane.io/v1beta1
      kind: Resources
      resources:
      - name: hello
        base:
          apiVersion: v1
          kind: ConfigMap
          data:
            hello: contribfest
EOF
cat >"$tmp/smoke/functions.yaml" <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
  annotations:
    render.crossplane.io/runtime: Development
    render.crossplane.io/runtime-development-target: 127.0.0.1:$SMOKE_PORT
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:$PT_VERSION
EOF
if [ -x "$pt" ] && [ -x "$core" ] && command -v crossplane >/dev/null; then
  "$pt" --insecure --address=127.0.0.1:$SMOKE_PORT >"$tmp/pt-run.log" 2>&1 &
  pt_pid=$!
  for _ in $(seq 1 40); do listening $SMOKE_PORT && break; sleep 0.25; done
  start=$SECONDS
  if (cd "$tmp/smoke" && crossplane composition render xr.yaml composition.yaml functions.yaml \
    --crossplane-binary="$core") >"$tmp/render.out" 2>&1 && grep -q "hello: contribfest" "$tmp/render.out"; then
    pass "crossplane composition render ran function-patch-and-transform in $((SECONDS - start))s"
  else
    tail -5 "$tmp/render.out"
    fail "render didn't produce the expected ConfigMap"
  fi
  kill "$pt_pid" 2>/dev/null
  wait "$pt_pid" 2>/dev/null
  pt_pid=
else
  fail "skipped: install the tools above first"
fi

if [ $CHECK_ONLY = 0 ]; then
  step "Warming the Go caches so the labs work offline"
  if crossplane xpkg init warmup function-template-go -d "$tmp/warmup" -r >"$tmp/init.log" 2>&1 &&
    (cd "$tmp/warmup" && go mod download && go build ./... && go test ./... && go generate ./...) >"$tmp/warm.log" 2>&1; then
    pass "function-template-go: modules, build cache, and controller-gen for go generate"
    (cd "$tmp/warmup" && golangci-lint run ./... >/dev/null 2>&1)
    pass "golangci-lint cache"
  else
    tail -5 "$tmp/init.log" "$tmp/warm.log" 2>/dev/null
    fail "couldn't build function-template-go"
  fi
  if git clone -q --depth 1 "$FN_REPO" "$tmp/fn" 2>/dev/null; then
    if (cd "$tmp/fn" && go mod download && go build ./...) >/dev/null 2>&1; then
      pass "function-lifecycle modules"
    else
      fail "couldn't build function-lifecycle"
    fi
  else
    warn "couldn't clone $FN_REPO, skipped"
  fi
fi

step "Optional"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  pass "gh, logged in (Lab 5)"
else
  warn "gh missing or logged out: you can open your Lab 5 PR in the browser instead"
fi
if docker info >/dev/null 2>&1; then
  pass "docker (Lab 6, and building the package image in Lab 5)"
else
  warn "no Docker: fine for Labs 1–5. Lab 6, a take-home, needs it."
fi
missing=""
for t in kind kubectl helm; do command -v $t >/dev/null || missing="$missing $t"; done
[ -z "$missing" ] && pass "kind, kubectl, helm (Lab 6)" || warn "missing$missing: only Lab 6 needs them"

step "Your PATH"
if [ $path_ok = 1 ]; then
  pass "$BIN_DIR is on your PATH"
else
  case "${SHELL##*/}" in
    zsh) rc="~/.zshrc" ;;
    bash) [ $os = darwin ] && rc="~/.bash_profile" || rc="~/.bashrc" ;;
    *) rc="your shell's startup file" ;;
  esac
  fail "$BIN_DIR isn't on your PATH. Add this line to $rc, then open a new terminal:"
  echo "      export PATH=\"$BIN_DIR:\$PATH\""
fi

echo
if [ $ok = 1 ]; then
  echo "You're ready for the labs."
else
  echo "Fix the ✘ items above, then run ./scripts/setup.sh again."
  exit 1
fi
