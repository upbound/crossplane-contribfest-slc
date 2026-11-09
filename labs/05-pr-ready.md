# Lab 5: Operations, then PR-ready

**Objective**: Run the same function as a step of an Operation, so one
Operation can freeze a whole fleet of XRs. Then make it PR-ready: lint clean,
documented, and committed with a sign-off.

⏱ **10 minutes**

---

## 🎯 Learning Objectives

- Run one function in Compositions and in Operations, and declare both
  capabilities
- Read the resources an Operation requires, and return server-side apply
  patches
- Render an Operation without a cluster
- Run the lint CI runs, and get a branch PR-ready with a signed-off commit

## 📋 Prerequisites

- [ ] Completed Lab 4
- [ ] Your function running in terminal 1, and function-patch-and-transform in
  terminal 3 (Lab 2, Step 2)
- [ ] A terminal in `~/function-lifecycle`. Every command in this lab runs there.

## ✅ Verify Lab 4 Completion

```shell
./example/test.sh
```

It prints `PASS` for all seven examples.

---

## The idea

Labs 2–4 built a composition step: each XR's own annotation, field, or context
picks its mode. To freeze one XR, an operator runs `kubectl annotate`. To
freeze fifty XRs every Friday evening, you need something else.

An [Operation](https://docs.crossplane.io/latest/operations/operation/) runs a
function pipeline outside any Composition: once (Operation), on a schedule
(CronOperation), or when a resource changes (WatchOperation). The Operation
tells Crossplane which resources to pass the function, as *required
resources*. Crossplane applies whatever the function returns as desired
resources, with server-side apply.

So the same function gets a second job. In an Operation, it sets the mode
annotation on every XR the Operation selects. The composition step you built
applies that mode on each XR's next reconcile.

## Step 1: Get the starting code, the tests, and the examples

```shell
cd ~/function-lifecycle
git fetch https://github.com/upbound/function-lifecycle workshop/lab-05-start
git checkout FETCH_HEAD -- fn.go fn_test.go mode.go operation.go operation_test.go
git checkout FETCH_HEAD -- example/ README.md package/crossplane.yaml
```

The checkout adds `operation.go`, its tests in `operation_test.go`, and the
Operation examples. It also brings the finished README and package metadata,
and the finished Lab 4 code: `fn.go`, with `fn_test.go` and `mode.go` to
match it.

Have a look at `example/operation.yaml`. Its input sets `mode: ObserveOnly`,
and its `requirements` select every App labelled `freeze: "true"`.

## Step 2: Run as an Operation

Three markers show where your code goes. This lists them with their line
numbers:

```shell
grep -n 'TODO(lab-05)' fn.go operation.go package/crossplane.yaml
```

| Marker | Your code |
|---|---|
| `TODO(lab-05) 1`, `fn.go` | No XR means an Operation: hand over to `runOperation` |
| `TODO(lab-05) 2`, `operation.go` | Build the patch for each required resource |
| `TODO(lab-05) 3`, `package/crossplane.yaml` | Declare that the function also works in Operations |

Read `runOperation` in `operation.go` first. Two things in it are new:

- `request.GetRequiredResources(req)` returns the resources the Operation
  asked for, by requirement name. In `example/operation.yaml` that's `apps`.
- The patch holds only what identifies the resource, plus the annotation.
  Crossplane applies it with server-side apply, so the function owns that one
  annotation and nothing else on the XR.

For `TODO(lab-05) 3`: a function package without `capabilities` counts as
composition-only, and Crossplane won't run it in an Operation. A
`capabilities` list replaces that default, so list both.

```shell
go test -v -run TestRunOperation ./...
```

If the Go gets in your way, open the solution.

<details>
<summary>Show solution: all three markers</summary>

In `fn.go`, replace `TODO(lab-05) 1` with:

```go
	// An Operation has no XR. There the function sets the mode annotation on
	// the resources the Operation requires instead. See operation.go.
	if req.GetObserved().GetComposite() == nil {
		return f.runOperation(req, rsp), nil
	}
```

In `operation.go`, replace `TODO(lab-05) 2` and the `patch` line above it with:

```go
			patch := &unstructured.Unstructured{}
			patch.SetAPIVersion(r.Resource.GetAPIVersion())
			patch.SetKind(r.Resource.GetKind())
			patch.SetNamespace(r.Resource.GetNamespace())
			patch.SetName(r.Resource.GetName())
			patch.SetAnnotations(map[string]string{AnnotationMode: string(mode)})
```

In `package/crossplane.yaml`, replace `TODO(lab-05) 3` and `spec: {}` with:

```yaml
spec:
  # Without capabilities, Crossplane treats a function as composition-only.
  capabilities:
  - composition
  - operation
```

</details>

Then run every test:

```shell
go test -v ./...
```

## Step 3: Render the Operation

Restart the function in terminal 1 (`Ctrl-C`, then
`go run . --insecure --debug --address=127.0.0.1:9443`) so it runs your new
code. Then in terminal 2:

```shell
crossplane operation render example/operation.yaml example/functions.yaml \
  -e example/apps.yaml -r --crossplane-binary=$(which crossplane-core)
```

`-e` passes the three Apps in `example/apps.yaml` as if they were in the
cluster. In the output:

- The Operation's `status.appliedResourceRefs` lists `checkout` and
  `payments`, the two Apps labelled `freeze: "true"`. It leaves `sandbox`
  alone.
- Then comes the patch for each one. It has only the mode annotation.
- The result says `Set lifecycle.fn.crossplane.io/mode to ObserveOnly on 2
  resources`.

`example/cronoperation.yaml` runs the same pipeline at 17:00 every Friday.
Render it too:

```shell
crossplane operation render example/cronoperation.yaml example/functions.yaml \
  -e example/apps.yaml -r --crossplane-binary=$(which crossplane-core)
```

> 💡 Operations are alpha. On a cluster, start Crossplane with
> `--enable-operations`.

## Step 4: Lint

CI runs golangci-lint 2.12. Check that you have the same version, then run it:

```shell
golangci-lint --version
golangci-lint run ./...
```

The first line starts with `golangci-lint has version 2.12.0`. Another version
reports different issues. Run `./scripts/setup.sh` in the hub repo again, and
it tells you how to fix it.

It finds 12 `modernize` issues, all in `fn_test.go`. Go 1.26 accepts
`new("text")`, so the tests' `ptr("text")` helper isn't needed any more. One
command fixes all 12:

```shell
go fix ./...
```

That leaves the helper unused. Delete its four lines from `fn_test.go`, around
line 54:

```go
// ptr returns a pointer to the supplied value.
//
//go:fix inline
func ptr[T any](v T) *T { return new(v) }
```

```shell
golangci-lint run ./...
go test -v ./...
```

Lint reports `0 issues`, and the tests pass.

> 💡 The warning about `gomodguard` being deprecated comes from the template's
> `.golangci.yml`. That's another upstream fix you could make.

## Step 5: README and package metadata

Users read the README. Registries and the Marketplace show the
`meta.crossplane.io` annotations in `package/crossplane.yaml`. A good README
takes longer than this lab, so Step 1 brought the reference ones. Read both,
and make them yours.

The README covers what a user needs: what the function does, the modes, a
pipeline snippet, the precedence order, recipes such as "delete the XR, keep
the cloud resources", running it from an Operation, and the caveats. Change
anything you'd say differently. Writing one from scratch is a good take-home.

Then delete two template leftovers:

```shell
rm NOTES.txt init.sh
```

## Step 6: Commit it, PR-ready

Check that no lab markers are left. This prints nothing:

```shell
grep -rn 'TODO(lab-' --include='*.go' --include='*.yaml' .
```

If it finds a line, delete it. Then commit. Crossplane projects require a
[DCO](https://developercertificate.org/) sign-off on every commit. That's the
`-s`:

```shell
git switch -c pr-ready
git add -A
git commit -s -m "feat: add lifecycle modes per XR, in Compositions and Operations"
git log --oneline main..pr-ready
```

`main` still holds only the scaffold from Lab 1, so `pr-ready` carries the
whole function in one signed-off commit. That's what a maintainer would see in
your pull request. Opening it is the easy part. First, [Lab 6](06-e2e-stretch.md)
adds the check maintainers ask for next: an e2e test on a real control plane.

**Done early?** Pick an issue labelled `contribfest` on
[upbound/function-lifecycle](https://github.com/upbound/function-lifecycle/issues?q=is%3Aissue+is%3Aopen+label%3Acontribfest),
and comment that you're taking it. Work in a fork, next to your lab copy. Write
the test first, then the code, and get it to the same PR-ready state:
`go test -v ./...` passes, `golangci-lint run ./...` is clean, and every commit
is signed off.

---

## ✅ Done when

- The Operation render patches `checkout` and `payments`, and leaves `sandbox`
  alone
- `golangci-lint run ./...` reports `0 issues`, and `go test -v ./...` passes
- `git log --oneline main..pr-ready` shows your signed-off commit

When you're done for the day, stop both functions: `Ctrl-C` in terminals 1
and 3.

## 🛟 Stuck?

Jump to the finished Lab 5:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-05 && git read-tree -u --reset FETCH_HEAD
```

This replaces your files with the end of Lab 5 and leaves `main` at your
scaffold commit. Then do Step 6 as written.

**Next:** [Lab 6: Local e2e, the last check before a PR](06-e2e-stretch.md)
