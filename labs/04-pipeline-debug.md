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

The composition now has a third step, function-auto-ready. Our function sits in
the middle: after the steps that compose, before the step that only reads.

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

```go
// ConditionTypeLifecycleMode reports the active mode on the XR.
const ConditionTypeLifecycleMode = "LifecycleMode"
```

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

## Step 4: The debugging toolkit

Stop the function in terminal 1, then:

```shell
make -C example test
```

`make test` builds the function, starts it, renders every example, and checks
the output. It's the same kind of harness function-aws-query uses. Then poke
around by hand:

```shell
make -C example serve        # terminal 1: function with --debug logs

cd example                   # terminal 2
crossplane composition render xr-observe-only.yaml composition.yaml functions.yaml \
  --crossplane-version=v2.4.2 -r -x | less     # results + full XR with the LifecycleMode condition
crossplane composition render xr.yaml composition-environment.yaml functions.yaml \
  --crossplane-version=v2.4.2 -c \
  --context-values='apiextensions.crossplane.io/environment={"managementMode":"Deprovision"}'   # kind: Context
```

| Tool | Shows |
|---|---|
| `-r` / `--include-function-results` | Results from every step, in order |
| `-c` / `--include-context` | The pipeline context after the last step |
| `-x` / `--include-full-xr` | The XR, including conditions functions set |
| `-o` / `--observed-resources` | Fakes resources that already exist, to test updates |
| `--debug` on the function | Your `f.log.Debug` lines |
| `crossplane resource trace` | The live XR tree and its conditions, in a cluster |
| Pipeline inspector (alpha, Crossplane v2.2+) | Every request and response, in a cluster |

---

## ✅ Done when

`make -C example test` prints `PASS` for all seven examples.

## 🛟 Stuck?

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-04 && git reset --hard FETCH_HEAD
```

**Next:** [Lab 5: PR-ready](05-pr-ready.md)
