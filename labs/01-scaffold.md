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

- [ ] A Codespace from this repo, or a laptop that passes `./scripts/check-env.sh`
- [ ] Two terminals open

---

## Step 1: Scaffold

```shell
cd ~   # anywhere outside this repo
crossplane xpkg init function-lifecycle function-template-go -d function-lifecycle -r
cd function-lifecycle
```

> **⚠️ Use `-r`**: without it `xpkg init` asks whether to run `init.sh`, and
> the prompt fails in some terminals.

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

## Step 3: Commit, test, run

```shell
git init -b main && git add -A && git commit -s -m "chore: scaffold from function-template-go"
go test ./...
```

In **terminal 1**, run the function. It listens on `localhost:9443`:

```shell
go run . --insecure --debug
```

In **terminal 2**, render the example against it:

```shell
cd example
crossplane composition render xr.yaml composition.yaml functions.yaml \
  --include-function-results --crossplane-version=v2.4.2
```

`example/functions.yaml` sets `render.crossplane.io/runtime: Development`, so
render calls your local process instead of pulling an image.

---

## ✅ Done when

The render output ends with:

```yaml
kind: Result
message: 'Pipeline step "run-the-template": I was run with input "Hello world"!'
```

and terminal 1 logs `Running function`.

## 🛟 Stuck?

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-01 && git reset --hard FETCH_HEAD
```

**Next:** [Lab 2: Core logic](02-core-logic.md)
