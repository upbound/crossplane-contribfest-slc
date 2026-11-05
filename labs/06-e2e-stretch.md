# Lab 6: Local e2e, then mark the PR ready

**Objective**: Test your function on a real control plane on your laptop. Then
tick the e2e box in your draft PR and mark it ready for review.

⏱ **8 minutes**, on the cluster `./scripts/setup.sh --e2e` created before the
session

---

## 🎯 Learning Objectives

- Know what an e2e test catches that unit tests and render can't
- Install a function you built on a real control plane: image, package,
  registry, `Function`
- Turn that into a test anyone can rerun, and mark the PR ready

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

`e2e/` holds `cluster.sh`, which creates the control plane, `run.sh`, the test
itself, a two-line `Dockerfile`, and `manifests/`: the App XRD, a Composition
that wraps a ConfigMap in a provider-kubernetes `Object`, the functions, three
Apps, and the freeze Operation.

## Step 2: Check the control plane

`./scripts/setup.sh --e2e` created it before the session by running
`./e2e/cluster.sh`. These are the commands it ran:

```shell
kind create cluster --name lifecycle-e2e
docker run -d --name lifecycle-e2e-registry --network kind -p 127.0.0.1:5001:5000 registry:2
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm install crossplane crossplane-stable/crossplane --version 2.4.3 \
  --namespace crossplane-system --create-namespace --set 'args={--enable-operations}'
kubectl apply -f e2e/manifests/provider.yaml -f e2e/manifests/functions.yaml
kubectl apply -f e2e/manifests/definition.yaml
kubectl apply -f e2e/manifests/composition.yaml -f e2e/manifests/providerconfig.yaml
```

- The registry runs next to the cluster, on kind's Docker network. Your
  function's package goes there in Step 3.
- `--enable-operations` turns on Operations, which are still alpha.
- `provider.yaml` gives provider-kubernetes permission to manage ConfigMaps in
  the cluster. `functions.yaml` installs function-patch-and-transform and
  function-auto-ready. Your function comes next.

Point `kubectl` at the cluster, and check it:

```shell
kind export kubeconfig --name lifecycle-e2e
kubectl get providers.pkg.crossplane.io,functions.pkg.crossplane.io
kubectl get xrd
```

The provider and the two functions are `HEALTHY`, and the
`apps.example.crossplane.io` XRD is `ESTABLISHED`. No cluster? Run
`./e2e/cluster.sh`. It pulls about 1.5 GB of images, so it takes about 5
minutes.

## Step 3: Install your function

Crossplane installs a function from a package in a registry, and runs it as a
pod. Do it once by hand.

Build a Linux binary for kind's node, put it in an image with
`e2e/Dockerfile`, and load the image straight into kind:

```shell
TAG=dev-$(date +%s)
BUILD=$(mktemp -d)
CGO_ENABLED=0 GOOS=linux GOARCH=$(docker version --format '{{.Server.Arch}}') go build -o $BUILD/function .
cp e2e/Dockerfile $BUILD/
docker build -t function-lifecycle:$TAG $BUILD
kind load docker-image function-lifecycle:$TAG --name lifecycle-e2e
```

Build the package and push it to the local registry. The package holds
`package/crossplane.yaml` and the input CRD: what Crossplane reads to install
the function and check what it can do.

```shell
crossplane xpkg build -f package -o $BUILD/function.xpkg
crossplane xpkg push -f $BUILD/function.xpkg localhost:5001/function-lifecycle:$TAG
```

Install it. Crossplane runs inside the cluster, so it reaches the registry at
the registry's IP address on kind's network. A registry at a private IP address
is plain HTTP, so there's no TLS to set up. The `DeploymentRuntimeConfig` in
`e2e/manifests/function-lifecycle.yaml` runs the image you loaded.

```shell
REGISTRY=$(docker inspect -f '{{(index .NetworkSettings.Networks "kind").IPAddress}}' lifecycle-e2e-registry):5000
sed -e "s#FN_PACKAGE#$REGISTRY/function-lifecycle:$TAG#" -e "s#FN_IMAGE#function-lifecycle:$TAG#" e2e/manifests/function-lifecycle.yaml | kubectl apply -f -
kubectl get functions.pkg.crossplane.io function-lifecycle
```

After a few seconds, `HEALTHY` is `True`, and `PACKAGE` is the tag you just
built.

## Step 4: Run the e2e test

```shell
./e2e/run.sh
```

It repeats Step 3 with a fresh tag, so it always tests your current code. Then
it runs two scenarios and checks each result:

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

It takes under a minute.

## Step 5: Watch it catch what render can't

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

## Step 6: Commit the e2e test and mark the PR ready

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

## Step 7 (if you have time): Look around

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
