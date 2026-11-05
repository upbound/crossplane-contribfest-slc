# Lab 5: Operations and the PR

**Objective**: Run the same function as a step of an Operation, so one
Operation can freeze a whole fleet of XRs. Then get it past lint and open a
pull request.

⏱ **12 minutes**

---

## 🎯 Learning Objectives

- Run one function in Compositions and in Operations, and declare both
  capabilities
- Read the resources an Operation requires, and return server-side apply
  patches
- Render an Operation without a cluster
- Run the lint CI runs, and open a signed-off PR

## 📋 Prerequisites

- [ ] Completed Lab 4
- [ ] Your function running in terminal 1, and function-patch-and-transform in
  terminal 3 (Lab 2, Step 1)
- [ ] A terminal in `~/function-lifecycle`. Every command in this lab runs there.
- [ ] `gh auth status` shows you're logged in, or use the browser for the PR

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
git checkout FETCH_HEAD -- fn.go operation.go operation_test.go
git checkout FETCH_HEAD -- example/ README.md package/crossplane.yaml
```

The checkout adds `operation.go`, its tests in `operation_test.go`, and the
Operation examples. It also brings the finished README and package metadata,
and the finished Lab 4 code in `fn.go`. Your commits stay as they are.

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
Render it the same way, with `example/cronoperation.yaml` in place of
`example/operation.yaml`.

> 💡 Operations are alpha. On a cluster, start Crossplane with
> `--enable-operations`.

## Step 4: Lint

CI runs golangci-lint. Run the same version locally:

```shell
golangci-lint run ./...
```

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

## Step 6: Check the package builds (optional, needs Docker)

CI builds the multi-arch runtime image and the package on every pull request,
so you can skip this step. If you have Docker with BuildKit, build it locally:

```shell
docker build . --tag=runtime
crossplane xpkg build -f package --embed-runtime-image=runtime
```

> **⚠️** If `docker build` fails on `RUN --mount` or an empty
> `BUILDPLATFORM`, your Docker has no BuildKit. Colima without `buildx` is
> one example. Skip the step and let CI build it.

## Step 7: Commit and open a PR

Crossplane projects require a [DCO](https://developercertificate.org/) sign-off
on every commit. That's the `-s`:

```shell
git switch -c pr-ready
git add -A
git commit -s -m "feat: add lifecycle modes per XR, in Compositions and Operations"
```

`main` still holds only the scaffold from Lab 1, so your branch carries the
whole function.

**Path A: your own repo** (everyone)

```shell
git switch main
gh repo create function-lifecycle-lab --public --source . --push
git switch pr-ready && git push -u origin pr-ready
gh pr create --web
```

`--web` opens the pull request form in your browser, filled in with the
repo's PR template. Work through its checklist, and add one more line to it:

```text
- [ ] Ran the e2e test on a local cluster.
```

Then open it as a draft: use the arrow next to **Create pull request** and pick
**Create draft pull request**. A draft tells maintainers it isn't ready for
review yet. Unit tests and renders prove what your function returns. Only a
real control plane proves that Crossplane and the provider act on it. That's
[Lab 6](06-e2e-stretch.md): run the e2e test, tick the box, and mark the PR
ready. Meanwhile, watch CI run lint, tests, and a multi-arch package build on
your draft.

> 💡 Pushing `main` also starts CI there. On a new repo, its `push` job
> usually fails with a 403: it publishes the package to ghcr.io, and new repos
> don't give workflows permission to write packages. Your PR doesn't run that
> job, so ignore it.

**Path B: upstream** (fast finishers). Pick an issue labelled `contribfest` on
[upbound/function-lifecycle](https://github.com/upbound/function-lifecycle/issues?q=is%3Aissue+is%3Aopen+label%3Acontribfest)
and comment that you're taking it. Then work in a fresh fork, next to your
lab copy:

```shell
mkdir -p ~/upstream && cd ~/upstream
gh repo fork upbound/function-lifecycle --clone && cd function-lifecycle
git switch -c <issue-number>-short-name
```

Write the test first, then the code. If you change `example/`, stop the
function in terminal 1, run the fork's instead, and run `./example/test.sh`.
Then:

```shell
go test -v ./... && golangci-lint run ./...
git add -A && git commit -s -m "feat: <what it does>"
git push -u origin HEAD
gh pr create --web
```

Fill in the PR template. "Fixes #N" links the issue. The template also asks
whether you ran the e2e test, `./e2e/run.sh`. If you haven't yet, open the PR
as a draft.

---

## ✅ Done when

- The Operation render patches `checkout` and `payments`, and leaves `sandbox`
  alone
- You have a draft PR URL, and its CI is green or running

When you're done for the day, stop both functions: `Ctrl-C` in terminals 1
and 3.

## 🛟 Stuck?

Jump to the finished Lab 5:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-05 && git read-tree -u --reset FETCH_HEAD
```

This replaces your files with the end of Lab 5 and leaves `main` at your
scaffold commit. Then do Step 7 as written.

**Next:** [Lab 6 (take-home): Local e2e, then mark the PR ready](06-e2e-stretch.md),
and the [curated issues](../CURATED-ISSUES.md).
