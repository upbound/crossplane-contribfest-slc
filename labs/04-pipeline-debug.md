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
- [ ] Both terminals in `~/function-lifecycle`. Every command in this lab runs there.

## ✅ Verify Lab 3 Completion

```shell
go test ./...                                      # ok
make -C example render XR=xr-spec-mode.yaml        # ObserveOnly
```

---

## Step 1: Get the tests and the examples

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-04
git checkout FETCH_HEAD -- fn_test.go example/
```

You also get `example/test.sh`, a render test harness, and new `make` targets
to drive it. You use them in Step 4.

> 💡 In a real pipeline, function-lifecycle goes after every step that
> composes resources, and before steps that only read them, such as
> function-auto-ready.

## Step 2: Report the source

Make `resolveMode` return where the mode came from as a second value:

| Source | String |
|---|---|
| annotation | `"annotation " + AnnotationMode` |
| modeRef | `"modeRef " + in.ModeRef` |
| input mode | `"input mode"` |
| fallback | `"default"` |

Then use it:

```go
	policies, err := mode.Policies()
	if err != nil {
		response.Fatal(rsp, errors.Wrapf(err, "invalid mode from %s", source))
		return rsp, nil
	}
	f.log.Debug("Resolved lifecycle mode", "mode", mode, "source", source, "policies", policies)
```

## Step 3: Add a condition

Results become events on the XR. Events are throttled and expire. A condition
stays on the XR's status, so `kubectl get` and `crossplane resource trace` show
the active mode.

Add `fmt` to the imports in `fn.go`, and this constant:

```go
// ConditionTypeLifecycleMode reports the active mode on the XR.
const ConditionTypeLifecycleMode = "LifecycleMode"
```

Then replace the `response.Normalf` line at the end of `RunFunction`:

```go
	response.Normalf(rsp, "%s (from %s): set managementPolicies %v on %d managed resources (%d skipped)", mode, source, policies, applied, skipped)
	response.ConditionTrue(rsp, ConditionTypeLifecycleMode, string(mode)).
		WithMessage(fmt.Sprintf("Composed managed resources use managementPolicies %v (mode from %s)", policies, source)).
		TargetComposite()
```

Add `f.log.Debug("Set management policies", "resource", name, "policies", policies)`
inside the loop too. You see it when the function runs with `--debug`.

```shell
go test ./...
```

## Step 4: Run the render tests

Stop the function in terminal 1 (`Ctrl-C`). The test starts its own. Then:

```shell
make -C example test
```

`make test` builds the function, starts it, renders every example, and checks
the output. It's the same kind of harness function-aws-query uses.

## Step 5 (if you have time): Look inside the pipeline

In terminal 1, run the function with debug logs:

```shell
make -C example serve
```

In terminal 2, render by hand with the inspection flags:

```shell
# Results from every step, and the XR with its LifecycleMode condition
crossplane composition render example/xr-observe-only.yaml example/composition.yaml \
  example/functions.yaml --crossplane-binary=$(which crossplane-core) -r -x | less

# The pipeline context, as kind: Context
crossplane composition render example/xr.yaml example/composition-environment.yaml \
  example/functions.yaml --crossplane-binary=$(which crossplane-core) -c \
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

The rendered XR's status always shows the conditions functions set. Stop
`make serve` in terminal 1 (`Ctrl-C`) when you're done: Lab 5 starts with
`make test`, which needs the port.

---

## ✅ Done when

`make -C example test` prints `PASS` for all seven examples.

## 🛟 Stuck?

Jump to the finished Lab 4:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-04 && git read-tree -u --reset FETCH_HEAD
```

This replaces your files with the end of Lab 4 and leaves your commits as
they are.

**Next:** [Lab 5: PR-ready](05-pr-ready.md)
