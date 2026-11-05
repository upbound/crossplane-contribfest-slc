# Lab 3: Generalize with an input API

**Objective**: Let composition authors choose where the mode comes from: the XR
spec or status, or the pipeline context (for example an EnvironmentConfig).

⏱ **10 minutes**

---

## 🎯 Learning Objectives

- Design a function input that turns one use case into many
- Generate the input CRD with `go generate`
- Read the pipeline context, which is how functions talk to each other

## 📋 Prerequisites

- [ ] Completed Lab 2
- [ ] Your function running in terminal 1, and function-patch-and-transform in
  terminal 3 (Lab 2, Step 1)
- [ ] All terminals in `~/function-lifecycle`. Every command in this lab runs there.

## ✅ Verify Lab 2 Completion

```shell
go test -v ./...
crossplane composition render example/xr-provision.yaml example/composition.yaml \
  example/functions.yaml -r --crossplane-binary=$(which crossplane-core)
```

Tests pass, and the render's result says `2 managed resources (1 skipped)`.

---

## The idea

The annotation is great for operators. Platform teams want more:

- XR authors pick a mode with a field: `spec.parameters.managementMode`
- A platform-wide change freeze: one EnvironmentConfig with
  `managementMode: ObserveOnly`, loaded into the context by
  function-environment-configs

The function's input gets two fields, using the same `xxxRef` path grammar as
function-aws-query, function-azresourcegraph, and function-msgraph:

```yaml
input:
  apiVersion: lifecycle.fn.crossplane.io/v1beta1
  kind: Input
  mode: Full                                 # used when nothing else is set
  modeRef: spec.parameters.managementMode    # or status.…, or context.[key].path
```

Precedence: **annotation → modeRef → mode → Full**. The annotation stays the
operator's break-glass lever.

## Step 1: Get the tests and the examples

```shell
cd ~/function-lifecycle
git fetch https://github.com/upbound/function-lifecycle workshop/lab-03
git checkout FETCH_HEAD -- fn_test.go example/
```

Same repo as in Lab 2. The checkout copies only `fn_test.go` and
`example/` from the reference, so the code you wrote stays yours.

## Step 2: Define the input

Replace `input/v1beta1/input.go`:

```go
// Package v1beta1 contains the input type for this Function
// +kubebuilder:object:generate=true
// +groupName=lifecycle.fn.crossplane.io
// +versionName=v1beta1
package v1beta1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// Input configures how function-lifecycle picks the lifecycle mode. The XR's
// lifecycle.fn.crossplane.io/mode annotation always takes precedence.
// +kubebuilder:object:root=true
// +kubebuilder:storageversion
// +kubebuilder:resource:categories=crossplane
type Input struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	// Mode applies when there is no mode annotation and ModeRef doesn't
	// resolve to a value. Defaults to Full.
	// +kubebuilder:validation:Enum=Full;Provision;ObserveOnly;Deprovision
	// +optional
	Mode string `json:"mode,omitempty"`

	// ModeRef reads the mode from a field of the XR or the pipeline context.
	// It must start with spec., status., or context. Use brackets for keys
	// that contain dots, for example
	// context.[apiextensions.crossplane.io/environment].managementMode.
	// +optional
	ModeRef string `json:"modeRef,omitempty"`
}
```

```shell
go generate ./...
ls package/input
```

`package/input` now holds `lifecycle.fn.crossplane.io_inputs.yaml`, the CRD
for your input.

## Step 3: Read the input and resolve the mode

Replace the imports at the top of `fn.go`. Three are new: `strings`,
`fieldpath`, and `input/v1beta1`, back from Lab 1. Keep the groups as shown;
Lab 5's linter checks them.

```go
import (
	"context"
	"strings"

	"github.com/crossplane/crossplane-runtime/v2/pkg/fieldpath"

	"github.com/crossplane/function-sdk-go/errors"
	"github.com/crossplane/function-sdk-go/logging"
	fnv1 "github.com/crossplane/function-sdk-go/proto/v1"
	"github.com/crossplane/function-sdk-go/request"
	"github.com/crossplane/function-sdk-go/resource"
	"github.com/crossplane/function-sdk-go/response"

	"github.com/crossplane/function-lifecycle/input/v1beta1"
)
```

In `RunFunction`, replace the annotation lookup from Lab 2 with:

```go
	// The input is optional. Without it we rely on the annotation alone.
	in := &v1beta1.Input{}
	if req.GetInput() != nil {
		if err := request.GetInput(req, in); err != nil {
			response.Fatal(rsp, errors.Wrapf(err, "cannot get Function input from %T", req))
			return rsp, nil
		}
	}

	mode, err := resolveMode(req, xr, in)
	if err != nil {
		response.Fatal(rsp, err)
		return rsp, nil
	}
```

The tests now expect the plain `unknown mode "Orphan": …` message, so return
`response.Fatal(rsp, err)` when `mode.Policies()` fails.

Then add the two helpers and fill in the `TODO`s:

```go
// resolveMode returns the lifecycle mode. In order of precedence it comes from
// the XR's mode annotation, the field ModeRef points to, the input's mode, or
// defaults to Full.
func resolveMode(req *fnv1.RunFunctionRequest, xr *resource.Composite, in *v1beta1.Input) (Mode, error) {
	// TODO: annotation, then lookup(in.ModeRef) if it's set and non-empty,
	// then in.Mode, then ModeFull.
}

// lookup returns the string at the supplied spec., status., or context. path.
// It returns an empty string if nothing is set at the path.
func lookup(req *fnv1.RunFunctionRequest, xr *resource.Composite, ref string) (string, error) {
	var v string
	var err error
	switch {
	case strings.HasPrefix(ref, "spec."), strings.HasPrefix(ref, "status."):
		v, err = xr.Resource.GetString(ref)
	case strings.HasPrefix(ref, "context."):
		v, err = fieldpath.Pave(req.GetContext().AsMap()).GetString(strings.TrimPrefix(ref, "context."))
	default:
		return "", errors.Errorf("modeRef %q must start with spec., status., or context.", ref)
	}
	if fieldpath.IsNotFound(err) {
		return "", nil
	}
	return v, errors.Wrapf(err, "cannot resolve modeRef %q", ref)
}
```

`fieldpath` understands the `[key.with.dots]` bracket syntax that context
keys need.

```shell
go mod tidy
go test -v ./...
```

## Step 4: Render from the spec and from the context

Restart the function in terminal 1 (`Ctrl-C`, then
`go run . --insecure --debug --address=127.0.0.1:9443`), then in terminal 2:

```shell
crossplane composition render example/xr-spec-mode.yaml example/composition.yaml \
  example/functions.yaml -r --crossplane-binary=$(which crossplane-core)
```

The second render uses `composition-environment.yaml`, which reads the mode
from the pipeline context:

```shell
crossplane composition render example/xr.yaml example/composition-environment.yaml \
  example/functions.yaml -r --crossplane-binary=$(which crossplane-core) \
  --context-values='apiextensions.crossplane.io/environment={"managementMode":"Deprovision"}'
```

`--context-values` fakes what function-environment-configs would put in the
context, so you can test the change-freeze story without a cluster.

---

## ✅ Done when

- `go test -v ./...` passes, and the list includes the new cases
  `ModeRefFromContext` and `AnnotationBeatsModeRef`
- `xr-spec-mode.yaml` renders `ObserveOnly`, and the context render shows `Deprovision`

**Bonus:** what should happen when `modeRef` and an EnvironmentConfig disagree?
"Most restrictive wins" is a [curated issue](../CURATED-ISSUES.md).

## 🛟 Stuck?

Jump to the finished Lab 3:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-03 && git read-tree -u --reset FETCH_HEAD
```

This replaces your files with the end of Lab 3 and leaves your commits as
they are. Restart the function in terminal 1 afterwards.

**Next:** [Lab 4: Real pipeline and debugging](04-pipeline-debug.md)
