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
- [ ] Both terminals in `~/function-lifecycle`. Every command in this lab runs there.

## ✅ Verify Lab 1 Completion

```shell
go test -v ./...
```

It passes.

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

## Step 1: Get the tests and the examples

The tests are written for you. Your job is to make them pass.

```shell
cd ~/function-lifecycle
git fetch https://github.com/upbound/function-lifecycle workshop/lab-02
git checkout FETCH_HEAD -- fn_test.go example/
go test -v ./...
```

That's the repo you scaffolded in Lab 1. The checkout copies only `fn_test.go` and
`example/` from the reference, so the code you wrote stays yours.

The tests fail. That's expected: they describe code you haven't written yet.

Have a look at `example/composition.yaml`. Step `compose` uses
function-patch-and-transform to compose a Bucket, a provider-kubernetes
Object, and a plain ConfigMap. Step `lifecycle` is yours.

`example/functions.yaml` runs both functions locally: yours on port 9443,
function-patch-and-transform on 9444. Open a **third terminal** and start
function-patch-and-transform, which `setup.sh` installed:

```shell
cd ~/function-lifecycle
function-patch-and-transform --insecure --address=127.0.0.1:9444
```

It prints nothing, and that's fine. Leave it running until the end of Lab 4.

## Step 2: Map modes to policies

Create `mode.go`:

```go
package main

import (
	"github.com/crossplane/function-sdk-go/errors"
)

// Mode is a lifecycle mode. Each mode maps to a set of management policies
// that crossplane-runtime supports.
type Mode string

// Supported lifecycle modes.
const (
	ModeFull        Mode = "Full"
	ModeProvision   Mode = "Provision"
	ModeObserveOnly Mode = "ObserveOnly"
	ModeDeprovision Mode = "Deprovision"
)

var policies = map[Mode][]string{
	ModeFull:        {"*"},
	ModeProvision:   {"Observe", "Create", "Update", "LateInitialize"},
	ModeObserveOnly: {"Observe"},
	ModeDeprovision: {"Observe", "Create", "Delete"},
}

// Policies returns the management policies for the mode.
func (m Mode) Policies() ([]string, error) {
	p, ok := policies[m]
	if !ok {
		return nil, errors.Errorf("unknown mode %q: must be one of Full, Provision, ObserveOnly, Deprovision", m)
	}
	return p, nil
}
```

## Step 3: Write `RunFunction`

Replace all of `fn.go` with this file, then fill in the three `TODO`s. It
drops the template's `input/v1beta1` import for now; Lab 3 brings it back.

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

	// TODO 1: start from ModeFull. If the XR has the AnnotationMode
	// annotation, use its value. Hint: xr.Resource.GetAnnotations().

	// TODO 2: get the policies with mode.Policies(). On error, return
	// response.Fatal(rsp, errors.Wrapf(err, "invalid %s annotation", AnnotationMode)).
	// Fail closed: a typo must never fall back to Full.

	desired, err := request.GetDesiredComposedResources(req)
	if err != nil {
		response.Fatal(rsp, errors.Wrap(err, "cannot get desired composed resources"))
		return rsp, nil
	}

	var applied, skipped int
	for name, dr := range desired {
		// TODO 3: if dr isn't a managed resource (see isManaged), log it with
		// f.log.Debug("Skipping a resource that isn't managed", "resource", name),
		// count it in skipped, and continue. Otherwise set its policies with
		// dr.Resource.SetValue("spec.managementPolicies", policies), return a
		// fatal result if that fails, and count it in applied.
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

> **⚠️ Don't build a new desired state from scratch.** Earlier steps put
> resources there. If you drop them, Crossplane deletes them.

## Step 4: Make it green

```shell
go test -v ./...
```

Read the failures: `-want` is the expected response, `+got` is yours.

## Step 5: Render the real pipeline

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

This replaces your files with the end of Lab 2 and leaves your commits as
they are, which Lab 5 relies on. Restart the function in terminal 1 afterwards.

**Next:** [Lab 3: Generalize with an input API](03-generalize-input.md)
