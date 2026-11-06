# Lab 6: Local e2e, the last check before a PR

**Objective**: Test your function on a real control plane on your laptop, and
commit the test with it. Then your branch is PR-ready.

⏱ **10 minutes**, on the cluster `./scripts/setup.sh --e2e` created before the
session

---

## 🎯 Learning Objectives

- Know what an e2e test catches that unit tests and render can't
- Install a function you built on a real control plane: image, package,
  registry, `Function`
- Turn that into a test anyone can rerun, and commit it with your function

## 📋 Prerequisites

- [ ] Completed Lab 5: your function is committed on the `pr-ready` branch
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

## Step 4: Try the modes by hand

The examples from Labs 2–4 are all one App, `my-app`, each with a different
mode. This time they run on a real control plane. Create it with no mode set:

```shell
kubectl apply -f example/xr.yaml
kubectl wait apps.example.crossplane.io my-app -n default --for condition=Ready --timeout 2m
crossplane resource trace apps.example.crossplane.io my-app -n default
```

```text
NAME                                         SYNCED   READY   STATUS
App/my-app (default)                         True     True    Available
├─ Object/my-app-b8788b47b034 (default)      True     True    Available
└─ ConfigMap/my-app-1051dc8fe27f (default)   -        -
```

The `Object` is a managed resource, so your function set its policies. The
plain ConfigMap isn't, so your function skipped it. See the policies, and the
`LifecycleMode` condition from Lab 4:

```shell
kubectl get objects.kubernetes.m.crossplane.io -n default -l crossplane.io/composite=my-app -o custom-columns=NAME:.metadata.name,POLICIES:.spec.managementPolicies
kubectl get apps.example.crossplane.io my-app -n default -o jsonpath='{.status.conditions[?(@.type=="LifecycleMode")].message}{"\n"}'
```

`POLICIES` is `[*]`, and the condition says
`Composed managed resources use managementPolicies [*] (mode from input mode)`.

Freeze it with the annotation:

```shell
kubectl apply -f example/xr-observe-only.yaml
```

After a few seconds, check the policies and the condition again:

```shell
kubectl get objects.kubernetes.m.crossplane.io -n default -l crossplane.io/composite=my-app -o custom-columns=NAME:.metadata.name,POLICIES:.spec.managementPolicies
kubectl get apps.example.crossplane.io my-app -n default -o jsonpath='{.status.conditions[?(@.type=="LifecycleMode")].message}{"\n"}'
```

Now the `Object` has `[Observe]`, and the condition says the mode came from
the annotation. `example/xr-spec-mode.yaml` does the same through
`spec.parameters.managementMode` and `modeRef`, if you want to try that too.

Now a typo:

```shell
kubectl apply -f example/xr-invalid.yaml
crossplane resource trace apps.example.crossplane.io my-app -n default
kubectl get objects.kubernetes.m.crossplane.io -n default -l crossplane.io/composite=my-app -o custom-columns=NAME:.metadata.name,POLICIES:.spec.managementPolicies
```

The App shows `SYNCED False` with `unknown mode "Orphan"`, and the `Object`
keeps the policies it had, `[Observe]`. The function fails closed, on a real cluster too.

Last, Provision, then delete the App:

```shell
kubectl apply -f example/xr-provision.yaml
```

After a few seconds, check the policies again:

```shell
kubectl get objects.kubernetes.m.crossplane.io -n default -l crossplane.io/composite=my-app -o custom-columns=NAME:.metadata.name,POLICIES:.spec.managementPolicies
```

`POLICIES` shows `[Observe Create Update LateInitialize]`. If it still shows
`[Observe]`, wait a few seconds and run that command again. Then delete the
App, and look for its ConfigMap:

```shell
kubectl delete apps.example.crossplane.io my-app -n default
kubectl get configmap my-app-config -n default
```

The App is gone, and its ConfigMap is still there. That's the Lab 2 recipe:
delete an XR, keep what it manages.

Now the CronOperation from Lab 5. Create the three Apps from
`example/apps.yaml`. Two of them are labelled `freeze: "true"`:

```shell
kubectl apply -f example/apps.yaml
kubectl wait apps.example.crossplane.io payments checkout sandbox -n default --for condition=Ready --timeout 2m
```

Create the CronOperation. It freezes those Apps at 17:00 every Friday:

```shell
kubectl apply -f example/cronoperation.yaml
kubectl get cronoperations.ops.crossplane.io
```

Nobody wants to wait until Friday. Make it run every minute, and wait for its
first run. That takes up to a minute:

```shell
kubectl patch cronoperations.ops.crossplane.io weekend-freeze --type merge -p '{"spec":{"schedule":"* * * * *"}}'
kubectl wait cronoperations.ops.crossplane.io weekend-freeze --for=jsonpath='{.status.lastSuccessfulTime}' --timeout 2m
```

Each run is an Operation that the CronOperation creates, named after it and
labelled with it:

```shell
kubectl get operations.ops.crossplane.io -l ops.crossplane.io/cronoperation=weekend-freeze
```

```text
NAME                        SYNCED   SUCCEEDED   AGE
weekend-freeze-1793965440   True     True        5s
```

See which Apps the first run changed:

```shell
kubectl get operations.ops.crossplane.io -l ops.crossplane.io/cronoperation=weekend-freeze -o jsonpath='{range .items[0].status.appliedResourceRefs[*]}{.kind}/{.name}{"\n"}{end}'
```

It lists `App/payments` and `App/checkout`. If the e2e test ran on this
cluster before, it lists `App/frozen` too: an App the test leaves behind,
labelled the same way.

Now look at the Apps' mode annotation, and at the policies your composition
step set on their Objects:

```shell
kubectl get apps.example.crossplane.io payments checkout sandbox -n default -o custom-columns='NAME:.metadata.name,MODE:.metadata.annotations.lifecycle\.fn\.crossplane\.io/mode'
kubectl get objects.kubernetes.m.crossplane.io -n default -l 'crossplane.io/composite in (payments,checkout,sandbox)' -o custom-columns='APP:.metadata.labels.crossplane\.io/composite,POLICIES:.spec.managementPolicies'
```

```text
NAME       MODE
payments   ObserveOnly
checkout   ObserveOnly
sandbox    <none>

APP        POLICIES
checkout   [Observe]
payments   [Observe]
sandbox    [*]
```

The CronOperation's Operation set the annotation on the two labelled Apps.
Your composition step turned it into `[Observe]` on their Objects, and
`sandbox` stayed at Full. That's what Lab 5's render predicted, now on a real
control plane, on a schedule.

If an App still shows `[*]`, run the last command again in a few seconds. A
brand-new App gets many updates at once, and Crossplane can hold its next
reconcile back for up to a minute. The note below explains why.

Then stop the schedule, or it creates a new Operation every minute. Deleting
the CronOperation deletes its Operations too:

```shell
kubectl delete cronoperations.ops.crossplane.io weekend-freeze
```

> 💡 A change usually lands within seconds. If one takes up to a minute, look
> at the App's `Responsive` condition. `WatchCircuitOpen` means Crossplane
> slowed down reconciles of an XR that changed many times in a few seconds. It
> catches up by itself.

## Step 5: Run the e2e test

```shell
./e2e/run.sh
```

It repeats Step 3 with a fresh tag, so it always tests your current code. Then
it runs two scenarios like the ones you just tried by hand, and checks each
result:

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

## Step 6: Watch it catch what render can't

Break the package. In `package/crossplane.yaml`, delete the `- operation` line
under `capabilities`. Render the Operation as in Lab 5, with your function
still running in terminal 1:

```shell
crossplane operation render example/operation.yaml example/functions.yaml \
  -e example/apps.yaml -r --crossplane-binary=$(which crossplane-core)
```

It still works: render never reads the package metadata. Now run the e2e test
again:

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
would fail. Put the `- operation` line back, and run the e2e test once more.
It passes:

```shell
./e2e/run.sh
```

## Step 7: Commit the e2e test, PR-ready

```shell
git add e2e/
git commit -s -m "test: add a local e2e test on kind"
git log --oneline main..pr-ready
```

Your branch is PR-ready: unit tests, lint, renders, and an e2e test anyone can
rerun with `./e2e/cluster.sh` and `./e2e/run.sh`. Every commit is signed off.
function-lifecycle's PR template asks whether you ran the e2e test, so when you
open a PR upstream, you can tick that box.

## Clean up, after the session

```shell
kind delete cluster --name lifecycle-e2e
docker rm -f lifecycle-e2e-registry
```

---

## ✅ Done when

- `./e2e/run.sh` prints `All e2e checks passed.`
- `git log --oneline main..pr-ready` shows two signed-off commits: your
  function and its e2e test

## 🛟 Stuck?

`kind create cluster` fails with `could not find a log line that matches
"Reached target .*Multi-User System.*"`: usually other kind clusters use up
Docker's inotify limit. Delete the ones you don't need with
`kind delete cluster --name <name>`, or raise the limit as kind's
[known issues](https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files) page shows.

More in [HELPERS](../HELPERS.md#common-problems).

**Next:** [Curated issues](../CURATED-ISSUES.md).
[#12](https://github.com/upbound/function-lifecycle/issues/12) runs this e2e test
in CI.
