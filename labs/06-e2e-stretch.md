# Lab 6: Local e2e, then mark the PR ready

**Objective**: Test your function on a real control plane on your laptop. Then
tick the e2e box in your draft PR and mark it ready for review.

⏱ **8 minutes**, on the cluster `./scripts/setup.sh --e2e` created before the
session

---

## 🎯 Learning Objectives

- Know what an e2e test catches that unit tests and render can't
- Build your function from your working tree and test it on a local kind
  cluster
- Keep a PR as a draft until it's proven, then mark it ready

## 📋 Prerequisites

- [ ] Completed Lab 5, with a draft PR
- [ ] Docker running, plus kind, kubectl, and helm. `setup.sh` doesn't install
  these.
- [ ] The `lifecycle-e2e` cluster from `./scripts/setup.sh --e2e`. Without it,
  the first run pulls about 1.5 GB of images, which conference Wi-Fi won't
  finish in time.
- [ ] About 4 GB of free memory for Docker

No Docker? Pair up with a neighbor, or watch the presenter run it on the
projector. If the session runs late, the presenter runs it on the projector for
everyone, and you finish it at home.

## Why e2e

Render runs your function against a pretend cluster. It proves what your
function returns. It can't prove what happens next:

- Crossplane installs your package and checks it. For example, an Operation
  only runs a function whose package declares the `operation` capability.
  Render never reads `package/crossplane.yaml`.
- The provider acts on `managementPolicies`. Deleting a Provision XR must
  leave its resources behind.
- Crossplane applies an Operation's patch with server-side apply, using its own
  permissions.

---

## Step 1: Get the e2e test

```shell
cd ~/function-lifecycle
git fetch https://github.com/upbound/function-lifecycle workshop/lab-06
git checkout FETCH_HEAD -- e2e/
```

Open `e2e/run.sh`. The first half sets up a kind cluster. The second half runs
two scenarios and prints `PASS` or `FAIL` for each check. `e2e/manifests/`
holds the App XRD, a Composition that wraps a ConfigMap in a provider-kubernetes
`Object`, three Apps, and the freeze Operation.

## Step 2: Run it

```shell
./e2e/run.sh
```

It uses the kind cluster called `lifecycle-e2e`, and creates it if it's
missing. The cluster has:

- Crossplane 2.4.3, started with `--enable-operations`
- provider-kubernetes, function-patch-and-transform, and function-auto-ready
- your function, built from your working tree and pushed to a local registry
- the App XRD and Composition, and three Apps

Then it runs the scenarios:

```text
==> Scenario 1: Provision, then delete the App. Its ConfigMap survives.
PASS  Provision sets the Object's policies
PASS  the ConfigMap outlives the App

==> Scenario 2: an Operation freezes the Apps labelled freeze: "true".
PASS  the Operation succeeds
PASS  the Operation annotates the labelled App
PASS  the composition applies ObserveOnly
PASS  the other App keeps Full

All e2e checks passed.
```

On the warm cluster it rebuilds only your function and takes under a minute.
Without the warm-up, the first run takes about 5 minutes.

## Step 3: Watch it catch what render can't

Break the package. In `package/crossplane.yaml`, delete the `- operation` line
under `capabilities`. Render the Operation as in Lab 5, and it still works:
render never reads the package metadata. Run the e2e test again:

```shell
./e2e/run.sh
```

The e2e Operation sets `retryLimit: 1`, so Crossplane gives up after the first
failure, about half a minute in:

```text
FAIL  the Operation succeeds
      Succeeded: failure limit of 1 reached
      ValidPipeline: function capability check failed: function "function-lifecycle" (active revision "…") is missing required capabilities: operation
```

Your function would have shipped like that, and every Operation that uses it
would fail. Put the line back, run `./e2e/run.sh` again, and it passes.

## Step 4 (if you have time): Look around

The cluster stays up after the test:

```shell
kubectl get apps.example.crossplane.io,managed -n default
crossplane resource trace apps.example.crossplane.io frozen -n default
kubectl get operations.ops.crossplane.io freeze-apps -o yaml
```

Freeze `free` by hand, and watch its `Object` change:

```shell
kubectl annotate apps.example.crossplane.io free -n default lifecycle.fn.crossplane.io/mode=ObserveOnly
kubectl get objects.kubernetes.m.crossplane.io -n default -o custom-columns=NAME:.metadata.name,POLICIES:.spec.managementPolicies
```

## Step 5: Commit the e2e test and mark the PR ready

```shell
git add e2e/
git commit -s -m "test: add a local e2e test on kind"
git push
```

On GitHub, tick **Ran the e2e test on a local cluster** in your PR's
description. Then mark it ready for review:

```shell
gh pr ready
```

CI runs on the new commit. Your PR now carries an e2e test, and anyone can
run it with one command.

## Clean up, after the session

```shell
kind delete cluster --name lifecycle-e2e
docker rm -f lifecycle-e2e-registry
```

---

## ✅ Done when

- `./e2e/run.sh` prints `All e2e checks passed.`
- Your PR is ready for review, with the e2e box ticked

## 🛟 Stuck?

`kind create cluster` fails with `could not find a log line that matches
"Reached target .*Multi-User System.*"`: usually other kind clusters use up
Docker's inotify limit. Delete the ones you don't need with
`kind delete cluster --name <name>`, or raise the limit as kind's
[known issues](https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files) page shows.

More in [HELPERS](../HELPERS.md#common-problems).

**Next:** [Curated issues](../CURATED-ISSUES.md). Number 11 runs this e2e test
in CI.
