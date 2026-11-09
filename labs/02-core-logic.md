# Lab 2: Core logic

**Objective**: Read a lifecycle mode from an XR annotation and set
`spec.managementPolicies` on every composed managed resource.

⏱ **15 minutes**

---

## 🎯 Learning Objectives

- See the pipeline as middleware: earlier steps compose resources, your step
  rewrites them
- Read the observed XR and the desired composed resources with the SDK
- Fail closed on bad input with a fatal result
- Make table-driven tests pass

## 📋 Prerequisites

- [ ] Completed Lab 1
- [ ] Terminals 1 and 2 from Lab 1, in `~/function-lifecycle`. Every command in
  this lab runs there.

## ✅ Verify Lab 1 Completion

```shell
go test -v ./...
```

It passes.

## 🖥️ Your terminals

From this lab on, you use three:

| Terminal | Runs | |
|---|---|---|
| 1 | Your function, `go run . --insecure --debug --address=127.0.0.1:9443` | From Lab 1. Restart it after every code change. |
| 2 | Your commands: tests and renders | Every command, unless the lab names another terminal |
| 3 | function-patch-and-transform | **New.** You start it in Step 2, and it runs until the end of Lab 4. |

---

## The idea

| Mode | `managementPolicies` |
|---|---|
| `Full` (default) | `["*"]` |
| `Provision` | `[Observe, Create, Update, LateInitialize]`. Never deletes, so deleting the XR orphans its resources. |
| `ObserveOnly` | `[Observe]` |
| `Deprovision` | `[Observe, Create, Delete]` |

An operator annotates the XR with `lifecycle.fn.crossplane.io/mode: Provision`,
and every managed resource it composes follows.

## Step 1: Get the starting code, the tests, and the examples

The tests are written for you. Your job is to make them pass.

```shell
cd ~/function-lifecycle
git fetch https://github.com/upbound/function-lifecycle workshop/lab-02-start
git checkout FETCH_HEAD -- fn.go mode.go fn_test.go example/
```

That's the repo you scaffolded in Lab 1. The checkout replaces `fn.go` with
this lab's outline, and adds `mode.go`, the tests, and the examples. There's
nothing to commit as you go: Lab 5 commits the whole function at once.

Have a look at `example/composition.yaml`. Step `compose` uses
function-patch-and-transform to compose a Bucket, a provider-kubernetes
Object, and a plain ConfigMap. Step `lifecycle` is yours.

## Step 2: Start function-patch-and-transform in a third terminal

`example/functions.yaml` runs both functions locally: yours on port 9443,
function-patch-and-transform on 9444. Render needs both running.

**Open a third terminal** and start function-patch-and-transform there.
`setup.sh` built it into `~/.local/bin`, next to `crossplane-core`.

**Terminal 3:**

```shell
cd ~/function-lifecycle
function-patch-and-transform --insecure --address=127.0.0.1:9444
```

It prints nothing, and that's fine. Leave it running until the end of Lab 4.
If the shell says `command not found`, `~/.local/bin` isn't on this
terminal's `PATH`: see the first row of
[HELPERS](../HELPERS.md#common-problems).

> 💡 **`bind: address already in use`?** Something still holds port 9444.
> See what it is:
>
> ```shell
> lsof -nP -iTCP:9444 -sTCP:LISTEN
> ```
>
> Stop it, and start function-patch-and-transform again:
>
> ```shell
> lsof -t -iTCP:9444 -sTCP:LISTEN | xargs kill
> function-patch-and-transform --insecure --address=127.0.0.1:9444
> ```

## Step 3: Read `mode.go`

`mode.go` maps each mode to its policies, as in the table above. `Policies()`
returns an error for a mode it doesn't know, so a typo can't fall back to
`Full`. You call it in the next step.

## Step 4: Fill in the `TODO`s

Open `fn.go`. `RunFunction` already gets the observed XR and the desired
composed resources. Three markers show where your code goes. This lists them
with their line numbers:

```shell
grep -n 'TODO(lab-02)' fn.go
```

| Marker | Your code |
|---|---|
| `TODO(lab-02) 1` | Read the mode from the XR's annotation |
| `TODO(lab-02) 2` | Fail closed on an unknown mode |
| `TODO(lab-02) 3` | Set the policies on each managed resource, and skip the rest |

Each marker says what to write. Until you fill in all three, `fn.go` doesn't
compile, and your editor shows errors such as `undefined: mode`. That's
expected.

Give the `TODO`s a few minutes. If the Go gets in your way, open the solution
and paste the whole file over `fn.go`.

<details>
<summary>Show solution: the finished <code>fn.go</code></summary>

```go
package main

import (
	"context"

	"github.com/crossplane/function-sdk-go/errors"
	"github.com/crossplane/function-sdk-go/logging"
	fnv1 "github.com/crossplane/function-sdk-go/proto/v1"
	"github.com/crossplane/function-sdk-go/request"
	"github.com/crossplane/function-sdk-go/resource"
	"github.com/crossplane/function-sdk-go/response"
)

// AnnotationMode on the XR selects the lifecycle mode of its composed
// resources.
const AnnotationMode = "lifecycle.fn.crossplane.io/mode"

// Function sets spec.managementPolicies on composed managed resources.
type Function struct {
	fnv1.UnimplementedFunctionRunnerServiceServer

	log logging.Logger
}

// RunFunction runs the Function.
func (f *Function) RunFunction(_ context.Context, req *fnv1.RunFunctionRequest) (*fnv1.RunFunctionResponse, error) {
	f.log.Info("Running function", "tag", req.GetMeta().GetTag())

	// response.To copies the desired state accumulated by previous pipeline
	// steps into our response. We only change what we need to.
	rsp := response.To(req, response.DefaultTTL)

	xr, err := request.GetObservedCompositeResource(req)
	if err != nil {
		response.Fatal(rsp, errors.Wrap(err, "cannot get observed composite resource"))
		return rsp, nil
	}

	mode := ModeFull
	if v, ok := xr.Resource.GetAnnotations()[AnnotationMode]; ok {
		mode = Mode(v)
	}

	// Fail closed: a typo in the mode must never fall back to Full.
	policies, err := mode.Policies()
	if err != nil {
		response.Fatal(rsp, errors.Wrapf(err, "invalid %s annotation", AnnotationMode))
		return rsp, nil
	}

	desired, err := request.GetDesiredComposedResources(req)
	if err != nil {
		response.Fatal(rsp, errors.Wrap(err, "cannot get desired composed resources"))
		return rsp, nil
	}

	var applied, skipped int
	for name, dr := range desired {
		if !isManaged(dr) {
			f.log.Debug("Skipping composed resource that is not a managed resource", "resource", name)
			skipped++
			continue
		}
		if err := dr.Resource.SetValue("spec.managementPolicies", policies); err != nil {
			response.Fatal(rsp, errors.Wrapf(err, "cannot set spec.managementPolicies on composed resource %q", name))
			return rsp, nil
		}
		applied++
	}

	if err := response.SetDesiredComposedResources(rsp, desired); err != nil {
		response.Fatal(rsp, errors.Wrap(err, "cannot set desired composed resources"))
		return rsp, nil
	}

	response.Normalf(rsp, "%s: set managementPolicies %v on %d managed resources (%d skipped)", mode, policies, applied, skipped)

	return rsp, nil
}

// isManaged returns true if the composed resource looks like a managed
// resource. Every managed resource has spec.forProvider. Plain Kubernetes
// objects and nested XRs don't.
func isManaged(dr *resource.DesiredComposed) bool {
	_, err := dr.Resource.GetValue("spec.forProvider")
	return err == nil
}
```

</details>

> **⚠️ Don't build a new desired state from scratch.** Earlier steps put
> resources there. If you drop them, Crossplane deletes them.

## Step 5: Make it green

```shell
go test -v ./...
```

Read the failures: `-want` is the expected response, `+got` is yours.

## Step 6: Render the real pipeline

Restart the function in terminal 1 so it runs your new code. Press `Ctrl-C`,
then:

```shell
go run . --insecure --debug --address=127.0.0.1:9443
```

Then in terminal 2, render the Provision example. Render calls both
functions: function-patch-and-transform composes, then yours sets the policies.

```shell
crossplane composition render example/xr-provision.yaml example/composition.yaml \
  example/functions.yaml -r --crossplane-binary=$(which crossplane-core)
```

Now render an XR with a mode that doesn't exist:

```shell
crossplane composition render example/xr-invalid.yaml example/composition.yaml \
  example/functions.yaml -r --crossplane-binary=$(which crossplane-core)
```

It fails closed: the function returns a fatal result, and render exits with
`unknown mode "Orphan": must be one of Full, Provision, ObserveOnly,
Deprovision`. That's the behavior you want.

---

## ✅ Done when

- `go test -v ./...` passes
- In the `xr-provision.yaml` render the Bucket and the Object have
  `managementPolicies: [Observe, Create, Update, LateInitialize]`, and the
  ConfigMap has none
- The result says `on 2 managed resources (1 skipped)`

**Bonus:** add a test case where an earlier step composed a nested XR (no
`spec.forProvider`). It should be skipped.

## 🛟 Stuck?

Jump to the finished Lab 2:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-02 && git read-tree -u --reset FETCH_HEAD
```

This replaces your files with the end of Lab 2. It doesn't touch your git
history, so there's nothing to commit first. Restart the function in terminal 1 afterwards.

**Next:** [Lab 3: Generalize with an input API](03-generalize-input.md)
