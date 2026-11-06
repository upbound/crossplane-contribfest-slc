#!/usr/bin/env bash
# Installs what the labs need, without Docker, and checks that it works. Run it
# before the session: the first run downloads about 250 MB, mostly Go modules,
# and then Labs 1-5 work offline.
#
#   ./scripts/setup.sh           # install what's missing, warm the Go caches, smoke test
#   ./scripts/setup.sh --e2e     # also create Lab 6's kind cluster, which needs Docker
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
E2E=0
for a in "$@"; do
  case $a in
    --check) CHECK_ONLY=1 ;;
    --e2e) E2E=1 ;;
    *) echo "Unknown option $a. Use --e2e, --check, or nothing."; exit 1 ;;
  esac
done
E2E_CLUSTER=${CLUSTER:-lifecycle-e2e}

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
# Lab 1 commits the scaffold, and that fails without a name and email.
if [ -n "$(git config user.name 2>/dev/null)" ] && [ -n "$(git config user.email 2>/dev/null)" ]; then
  pass "git identity: $(git config user.name) <$(git config user.email)>"
else
  fail "git has no name or email, and Lab 1 commits. Set them with:"
  echo "      git config --global user.name \"Your Name\" && git config --global user.email you@example.com"
fi
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
  short=$("$lint" version --short 2>/dev/null)
  pass "golangci-lint v${short#v}, built with go$lint_go ($lint)"
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

step "Smoke test: render a composition"
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
    pass "crossplane composition render, with Crossplane and function-patch-and-transform as local processes, in $((SECONDS - start))s"
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
  # The same template the labs start from. warm_lab3.go adds the import Lab 3
  # adds, so its go mod tidy finds every module in the cache.
  if crossplane xpkg init warmup function-template-go -d "$tmp/warmup" -r >"$tmp/init.log" 2>&1 &&
    (cd "$tmp/warmup" && go mod download && go build ./... && go test ./... && go generate ./... &&
      printf 'package main\n\nimport _ "github.com/crossplane/crossplane-runtime/v2/pkg/fieldpath"\n' >warm_lab3.go &&
      go mod tidy && go build ./...) >"$tmp/warm.log" 2>&1; then
    pass "function-template-go: modules, build cache, and controller-gen for go generate"
    (cd "$tmp/warmup" && golangci-lint run ./... >/dev/null 2>&1)
    pass "golangci-lint cache"
  else
    tail -5 "$tmp/init.log" "$tmp/warm.log" 2>/dev/null
    fail "couldn't build function-template-go"
  fi
  # The last workshop tag, not main: catch-ups bring in the tags' module
  # versions, and main may have moved on since.
  if git clone -q --depth 1 --branch workshop/lab-05 "$FN_REPO" "$tmp/fn" 2>/dev/null; then
    if (cd "$tmp/fn" && go mod download && go mod tidy && go test ./...) >/dev/null 2>&1; then
      pass "function-lifecycle modules"
    else
      fail "couldn't build function-lifecycle"
    fi
  else
    warn "couldn't clone $FN_REPO, skipped"
  fi
fi

# Lab 6 tests the function on a kind cluster. Labs 1-5 never use Docker.
step "Lab 6: the e2e test on a kind cluster"
missing=""
for t in docker kind kubectl helm; do command -v $t >/dev/null || missing="$missing $t"; done
if [ -n "$missing" ]; then
  warn "not installed:$missing. Labs 1–5 don't need them. Without them, pair up for Lab 6."
elif ! docker info >/dev/null 2>&1; then
  warn "docker, kind, kubectl, helm are installed, but Docker isn't running"
elif [ $E2E = 1 ] && [ $CHECK_ONLY = 0 ]; then
  pass "docker, kind, kubectl, helm"
  # Lab 6's first run pulls about 1.5 GB of images. Do it now, not on conference
  # Wi-Fi: create the cluster with the reference function's e2e/cluster.sh, and
  # run its e2e test once. Show the steps as they go, the full log on failure.
  echo "    creating the $E2E_CLUSTER cluster and running the e2e test, about 5 minutes the first time:"
  if git clone -q --depth 1 --branch workshop/lab-06 "$FN_REPO" "$tmp/e2e" 2>/dev/null; then
    (cd "$tmp/e2e" && ./e2e/cluster.sh && ./e2e/run.sh) 2>&1 | tee "$tmp/e2e.log" |
      grep --line-buffered -e '^==>' -e '^PASS' -e '^FAIL' | sed -u 's/^==> //; s/^/      /'
    if [ "${PIPESTATUS[0]}" = 0 ]; then
      pass "the e2e test passes, and $E2E_CLUSTER is ready for Lab 6. kubectl now points at it."
    else
      tail -15 "$tmp/e2e.log"
      fail "the e2e warm-up failed. Lab 6's page has fixes under Stuck?"
    fi
  else
    fail "couldn't clone $FN_REPO"
  fi
elif kind get clusters 2>/dev/null | grep -qx "$E2E_CLUSTER"; then
  pass "docker, kind, kubectl, helm, and the $E2E_CLUSTER cluster for Lab 6"
else
  pass "docker, kind, kubectl, helm"
  warn "no $E2E_CLUSTER cluster yet. Run ./scripts/setup.sh --e2e before the session, so Lab 6 doesn't pull images on conference Wi-Fi."
fi

step "Your PATH"
line="export PATH=\"$BIN_DIR:\$PATH\""
this_terminal=0
if [ $path_ok = 1 ]; then
  pass "$BIN_DIR is on your PATH"
else
  case "${SHELL##*/}" in
    zsh) rc=$HOME/.zshrc ;;
    bash) [ $os = darwin ] && rc=$HOME/.bash_profile || rc=$HOME/.bashrc ;;
    *) rc= ;;
  esac
  shown=${rc:+"~/${rc#"$HOME"/}"}
  if [ -n "$rc" ] && grep -qxF "$line" "$rc" 2>/dev/null; then
    added=1
  elif [ -n "$rc" ] && [ $CHECK_ONLY = 0 ] && [ -t 0 ] && [ -t 1 ]; then
    answer=
    read -r -p "  $BIN_DIR isn't on your PATH. Add it to $shown? [Y/n] " answer
    case $answer in
      [nN]*) added=0 ;;
      *) printf '\n# Crossplane ContribFest tools\n%s\n' "$line" >>"$rc" && added=1 ;;
    esac
  else
    added=0
  fi
  if [ $added = 1 ]; then
    pass "$BIN_DIR is on your PATH in new terminals ($shown)"
    this_terminal=1
  else
    fail "$BIN_DIR isn't on your PATH. Add this line to ${shown:-your shell startup file}, then open a new terminal:"
    echo "      $line"
  fi
fi

echo
if [ $ok = 1 ]; then
  echo "You're ready for the labs."
  if [ $this_terminal = 1 ]; then
    echo "This terminal doesn't have the new PATH yet. Run this here first, or open a new terminal:"
    echo "  $line"
  fi
else
  echo "Fix the ✘ items above, then run ./scripts/setup.sh again."
  exit 1
fi
