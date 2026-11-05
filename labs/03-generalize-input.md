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

## Step 1: Get the starting code, the tests, and the examples

```shell
cd ~/function-lifecycle
git fetch https://github.com/upbound/function-lifecycle workshop/lab-03-start
git checkout FETCH_HEAD -- fn.go fn_test.go input/ example/
```

Same repo as in Lab 2. The checkout replaces `fn.go` with the finished Lab 2
code plus this lab's outline, and `input/` with the new input type. It also
brings the new tests and examples. Your commits stay as they are.

## Step 2: Generate the input CRD

Open `input/v1beta1/input.go`. The `Input` has the two fields from the idea
above, `mode` and `modeRef`. The `+kubebuilder` comments become the CRD's
schema, so `mode` accepts only the four modes. Generate the CRD:

```shell
go generate ./...
ls package/input
```

`package/input` now holds `lifecycle.fn.crossplane.io_inputs.yaml`, the CRD
for your input.

## Step 3: Fill in `resolveMode`

Open `fn.go`. Here's what's new since Lab 2:

- `RunFunction` reads the optional input, then calls `resolveMode` instead of
  reading the annotation itself.
- `lookup` reads the string at a `spec.`, `status.`, or `context.` path.
  `fieldpath` understands the `[key.with.dots]` bracket syntax that context
  keys need.
- The `Policies()` error no longer mentions the annotation, because the mode
  can now come from elsewhere. Lab 4 adds the real source.

`resolveMode` is yours. Its three markers follow the order of precedence. This
lists them with their line numbers:

```shell
grep -n 'TODO(lab-03)' fn.go
```

| Marker | Your code |
|---|---|
| `TODO(lab-03) 1` | The annotation wins |
| `TODO(lab-03) 2` | Then the value at `modeRef` |
| `TODO(lab-03) 3` | Then the input's `mode` |

If none of them applies, `resolveMode` already returns `Full`.

If the Go gets in your way, open the solution and paste it over your
`resolveMode`.

<details>
<summary>Show solution: the finished <code>resolveMode</code></summary>

```go
// resolveMode returns the lifecycle mode. In order of precedence it comes from
// the XR's mode annotation, the field ModeRef points to, the input's mode, or
// defaults to Full.
func resolveMode(req *fnv1.RunFunctionRequest, xr *resource.Composite, in *v1beta1.Input) (Mode, error) {
	if v, ok := xr.Resource.GetAnnotations()[AnnotationMode]; ok {
		return Mode(v), nil
	}
	if in.ModeRef != "" {
		v, err := lookup(req, xr, in.ModeRef)
		if err != nil {
			return "", err
		}
		if v != "" {
			return Mode(v), nil
		}
	}
	if in.Mode != "" {
		return Mode(in.Mode), nil
	}
	return ModeFull, nil
}
```

</details>

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
