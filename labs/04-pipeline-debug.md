# Lab 4: Real pipeline and debugging

**Objective**: Make the function explain itself. Report where the mode came
from, put it in an XR condition, and use the debugging tools to see inside the
pipeline.

⏱ **8 minutes**

---

## 🎯 Learning Objectives

- Tell results (events) apart from conditions (status)
- Inspect a pipeline with `--include-function-results`, `--include-context`,
  and `--include-full-xr`
- Turn examples into a regression test with a render harness

## 📋 Prerequisites

- [ ] Completed Lab 3
- [ ] Your function running in terminal 1, and function-patch-and-transform in
  terminal 3 (Lab 2, Step 2)
- [ ] All terminals in `~/function-lifecycle`. Every command in this lab runs there.

## ✅ Verify Lab 3 Completion

```shell
go test -v ./...
crossplane composition render example/xr-spec-mode.yaml example/composition.yaml \
  example/functions.yaml -r -x --crossplane-binary=$(which crossplane-core)
```

Tests pass, and the render shows `ObserveOnly`.

---

## Step 1: Get the starting code, the tests, and the examples

```shell
cd ~/function-lifecycle
git fetch https://github.com/upbound/function-lifecycle workshop/lab-04-start
git checkout FETCH_HEAD -- fn.go fn_test.go example/
```

Same repo as in Lab 3. The checkout replaces `fn.go` with the finished Lab 3
code plus this lab's outline. It also brings the new tests and examples,
including `example/test.sh`, a render test harness you use in Step 4.

> 💡 In a real pipeline, function-lifecycle goes after every step that
> composes resources, and before steps that only read them, such as
> function-auto-ready.

Two markers show where your code goes. This lists them with their line
numbers:

```shell
grep -n 'TODO(lab-04)' fn.go
```

## Step 2: Report the source

`resolveMode` now returns a second value: where the mode came from.
`RunFunction` already uses it. The fatal error says `invalid mode from …`, the
result says `Provision (from …)`, and with `--debug` the function logs it. So
far every return passes `""`. Fill in the real sources at `TODO(lab-04) 1`:

| The mode came from | Source |
|---|---|
| The annotation | `"annotation " + AnnotationMode` |
| `modeRef` | `"modeRef " + in.ModeRef` |
| The input's `mode` | `"input mode"` |
| Nowhere | `"default"` |

## Step 3: Add a condition

Results become events on the XR. Events are throttled and expire. A condition
stays on the XR's status, so `kubectl get` and `crossplane resource trace` show
the active mode. Set one at `TODO(lab-04) 2`, at the end of `RunFunction`. The
`ConditionTypeLifecycleMode` constant is already there.

Give the `TODO`s a few minutes. If the Go gets in your way, open the solution.

<details>
<summary>Show solution: the finished <code>resolveMode</code> and the condition</summary>

Paste this over your `resolveMode`:

```go
// resolveMode returns the lifecycle mode and where it came from. In order of
// precedence it comes from the XR's mode annotation, the field ModeRef points
// to, the input's mode, or defaults to Full.
func resolveMode(req *fnv1.RunFunctionRequest, xr *resource.Composite, in *v1beta1.Input) (Mode, string, error) {
	if v, ok := xr.Resource.GetAnnotations()[AnnotationMode]; ok {
		return Mode(v), "annotation " + AnnotationMode, nil
	}
	if in.ModeRef != "" {
		v, err := lookup(req, xr, in.ModeRef)
		if err != nil {
			return "", "", err
		}
		if v != "" {
			return Mode(v), "modeRef " + in.ModeRef, nil
		}
	}
	if in.Mode != "" {
		return Mode(in.Mode), "input mode", nil
	}
	return ModeFull, "default", nil
}
```

Add `"fmt"` to the imports. Then replace the `TODO(lab-04) 2` comment, right
after `response.Normalf` at the end of `RunFunction`, with:

```go
	response.ConditionTrue(rsp, ConditionTypeLifecycleMode, string(mode)).
		WithMessage(fmt.Sprintf("Composed managed resources use managementPolicies %v (mode from %s)", policies, source)).
		TargetComposite()
```

</details>

```shell
go test -v ./...
```

## Step 4: Run the render tests

> 🔁 **Terminal 1: restart your function** so it runs your new code. Press
> `Ctrl-C`, then:
>
> ```shell
> go run . --insecure --debug --address=127.0.0.1:9443
> ```

**Terminal 2:**

```shell
./example/test.sh
```

It renders every example against your two running functions and checks the
output. Open it: it's a table of examples and the text each render must
contain, the same kind of harness function-aws-query uses.

## Step 5 (if you have time): Look inside the pipeline

Your function runs with `--debug`, so terminal 1 logs each resource it
changes. In terminal 2, render by hand with the inspection flags. This one shows the
results from every step, and the XR with its `LifecycleMode` condition:

```shell
crossplane composition render example/xr-observe-only.yaml example/composition.yaml \
  example/functions.yaml --crossplane-binary=$(which crossplane-core) -r -x | less
```

This one shows the pipeline context, as `kind: Context`:

```shell
crossplane composition render example/xr.yaml example/composition-environment.yaml \
  example/functions.yaml --crossplane-binary=$(which crossplane-core) -x -c \
  --context-values='apiextensions.crossplane.io/environment={"managementMode":"Deprovision"}'
```

| Tool | Shows |
|---|---|
| `-r` / `--include-function-results` | Results from every step, in order |
| `-c` / `--include-context` | The pipeline context after the last step |
| `-x` / `--include-full-xr` | Adds the input XR's spec and metadata to the rendered XR |
| `-o` / `--observed-resources` | Fakes resources that already exist, to test updates |
| `--debug` on the function | Your `f.log.Debug` lines |
| `crossplane resource trace` | The live XR tree and its conditions, in a cluster |
| Pipeline inspector (alpha, Crossplane v2.2+) | Every request and response, in a cluster |

The rendered XR's status always shows the conditions functions set.

---

## ✅ Done when

`./example/test.sh` prints `PASS` for all seven examples.

## 🛟 Stuck?

Jump to the finished Lab 4:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-04 && git read-tree -u --reset FETCH_HEAD
```

This replaces your files with the end of Lab 4. It doesn't touch your git
history, so there's nothing to commit first.

> 🔁 **Terminal 1: restart your function** so it runs the new code. Press
> `Ctrl-C`, then:
>
> ```shell
> go run . --insecure --debug --address=127.0.0.1:9443
> ```

**Next:** [Lab 5: Operations and the PR](05-pr-ready.md)
