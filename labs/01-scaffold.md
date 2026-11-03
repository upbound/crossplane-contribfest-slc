# Lab 1: Scaffold a function and render it

**Objective**: Go from an empty directory to a function that runs locally and
answers a real `crossplane composition render`.

⏱ **8 minutes**

---

## 🎯 Learning Objectives

- Scaffold a function from the official Go template
- Know what each file in the template is for
- Run a function locally and call it with `crossplane composition render`

## 📋 Prerequisites

- [ ] `./scripts/setup.sh` ends with `You're ready for the labs.`
- [ ] Two terminals open

---

## Step 1: Scaffold

```shell
cd ~
crossplane xpkg init function-lifecycle function-template-go -d function-lifecycle -r
cd function-lifecycle
```

Your function lives in `~/function-lifecycle`. Every command from here to
the end of Lab 5 runs in that directory, in both terminals.

> **⚠️ Use `-r`**: without it `xpkg init` asks whether to run `init.sh`, and
> the prompt fails in some terminals. `xpkg init` then prints the template's
> notes, which suggest running `./init.sh`. `-r` already did.

> **⚠️ Stay out of `/tmp`**: `xpkg init` fails with `path outside base dir`
> when the path goes through a symlink, and on macOS `/tmp` is one.

`init.sh` renames the module to `github.com/crossplane/function-lifecycle`. We
are all building the same upstream function today, so point it at the real
repo and finish the renames `init.sh` doesn't do:

```shell
perl -pi -e 's#github.com/crossplane/function-lifecycle#github.com/upbound/function-lifecycle#g' go.mod fn.go
perl -pi -e 's#function-template-go#function-lifecycle#g' package/crossplane.yaml
perl -pi -e 's#github.com/crossplane/function-template-go#github.com/upbound/function-lifecycle#g' .golangci.yml
```

> 💡 `init.sh` missing `package/crossplane.yaml` and `.golangci.yml` is a real
> bug in function-template-go. That's a contribution you can make today. See
> the [curated issues](../CURATED-ISSUES.md).

## Step 2: Tour the template

| File | What it's for |
|---|---|
| `fn.go` | `RunFunction`: your logic. Gets a `RunFunctionRequest`, returns a `RunFunctionResponse`. |
| `fn_test.go` | Table-driven unit tests. Fast, no cluster. |
| `main.go` | gRPC server and CLI flags. You rarely touch it. |
| `input/v1beta1/` | The schema of the function's `input:` in a Composition. `go generate` turns it into a CRD. |
| `package/crossplane.yaml` | Package metadata for `crossplane xpkg build`. |
| `example/` | An XR, a Composition, and a Functions file for `crossplane composition render`. |
| `Dockerfile`, `.github/workflows/ci.yml` | The runtime image and the CI that builds and pushes the package. |

## Step 3: Point render at your function

`example/functions.yaml` tells `crossplane composition render` how to reach
each function in the pipeline. The template already sets
`render.crossplane.io/runtime: Development`, so render calls a process running
on your machine instead of pulling the function's image. Add one line under it:

```yaml
  annotations:
    # This tells crossplane render to connect to the function locally.
    render.crossplane.io/runtime: Development
    render.crossplane.io/runtime-development-target: 127.0.0.1:9443   # add this
```

The default target is `localhost:9443`. On some networks, resolving
`localhost` adds about 10 seconds to every render. The IP never does.

## Step 4: Commit, test, run

```shell
git init -b main && git add -A && git commit -s -m "chore: scaffold"
go test ./...
```

In **terminal 1**, run the function:

```shell
go run . --insecure --debug --address=127.0.0.1:9443
```

`--address=127.0.0.1:9443` keeps it on your machine. The default listens on
every network interface, which makes macOS ask whether to accept incoming
connections.

Open **terminal 2**, go to the function, and render the example against it:

```shell
cd ~/function-lifecycle
crossplane composition render example/xr.yaml example/composition.yaml example/functions.yaml \
  --include-function-results --crossplane-binary=$(which crossplane-core)
```

`--crossplane-binary` runs Crossplane's render engine as a local process
instead of in a Docker container. It takes a path, not a command name, hence
the `$(which …)`.

---

## ✅ Done when

The render output includes:

```yaml
kind: Result
message: 'Pipeline step "run-the-template": I was run with input "Hello world"!'
```

and terminal 1 logs `Running function`.

## 🛟 Stuck?

Start from the reference scaffold. It already has the renames and the
`127.0.0.1` line:

```shell
mkdir -p ~/function-lifecycle && cd ~/function-lifecycle && git init -b main
git fetch https://github.com/upbound/function-lifecycle workshop/lab-01 && git reset --hard FETCH_HEAD
```

`git init` is harmless if the directory is already a repo.

**Next:** [Lab 2: Core logic](02-core-logic.md)
