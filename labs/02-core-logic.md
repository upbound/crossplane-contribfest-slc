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

## ✅ Verify Lab 1 Completion

```shell
go test ./...   # ok
```

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
git fetch https://github.com/upbound/function-lifecycle workshop/lab-02
git checkout FETCH_HEAD -- fn_test.go example/
go test ./...   # fails to compile: that's expected
```

Have a look at `example/composition.yaml`. Step `compose` uses
function-patch-and-transform to compose a Bucket, a provider-kubernetes
Object, and a plain ConfigMap. Step `lifecycle` is yours.

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

Replace `fn.go` with the outline below and fill in the three `TODO`s. The
imports you need are `errors`, `logging`, `fnv1`, `request`, `resource`, and
`response` from `github.com/crossplane/function-sdk-go`. Remove the
`input/v1beta1` import for now; Lab 3 brings it back.

```go
// AnnotationMode on the XR selects the lifecycle mode of its composed
// resources.
const AnnotationMode = "lifecycle.fn.crossplane.io/mode"

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

	// TODO 2: get the policies with mode.Policies(). On error return a fatal
	// result wrapped as "invalid <annotation> annotation". Fail closed: a typo
	// must never fall back to Full.

	desired, err := request.GetDesiredComposedResources(req)
	if err != nil {
		response.Fatal(rsp, errors.Wrap(err, "cannot get desired composed resources"))
		return rsp, nil
	}

	var applied, skipped int
	for name, dr := range desired {
		// TODO 3: skip resources that aren't managed resources (see isManaged)
		// and count them. Set the rest with
		// dr.Resource.SetValue("spec.managementPolicies", policies).
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
go test ./...
```

Read the failures: `-want` is the expected response, `+got` is yours.

## Step 5: Render the real pipeline

Restart the function in terminal 1 (`Ctrl-C`, then `go run . --insecure --debug`),
then in terminal 2:

```shell
make -C example render XR=xr-provision.yaml
make -C example render XR=xr-invalid.yaml   # fails closed
```

---

## ✅ Done when

- `go test ./...` passes
- In the `xr-provision.yaml` render the Bucket and the Object have
  `managementPolicies: [Observe, Create, Update, LateInitialize]`, and the
  ConfigMap has none
- The result says `on 2 managed resources (1 skipped)`

**Bonus:** add a test case where an earlier step composed a nested XR (no
`spec.forProvider`). It should be skipped.

## 🛟 Stuck?

```shell
# Start Lab 2 again from a clean Lab 1
git fetch https://github.com/upbound/function-lifecycle workshop/lab-01 && git reset --hard FETCH_HEAD
# Or jump to the finished Lab 2
git fetch https://github.com/upbound/function-lifecycle workshop/lab-02 && git reset --hard FETCH_HEAD
```

**Next:** [Lab 3: Generalize with an input API](03-generalize-input.md)
