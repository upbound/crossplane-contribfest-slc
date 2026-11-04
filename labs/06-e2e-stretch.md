# Lab 6 (take-home): See it on a cluster

**Objective**: Run the function in a real control plane. Freeze a resource,
then delete an XR without deleting what it manages.

⏱ **20 minutes**, most of it waiting for images

---

## 🎯 Learning Objectives

- Install functions and a provider into Crossplane v2
- Watch management policies change on live managed resources
- Orphan external resources safely, in two phases

## 📋 Prerequisites

- [ ] Docker, kind, helm, and kubectl. `setup.sh` doesn't install these.
- [ ] About 4 GB of free Docker disk

---

## Step 1: Create the control plane

From the root of this repo:

```shell
./demo/setup.sh
```

This creates a kind cluster with Crossplane 2.4.3, provider-kubernetes, and
three functions: patch-and-transform, lifecycle, and auto-ready. To use your
own build instead of the released package, push it first and then run:

```shell
FN_PACKAGE=ghcr.io/<you>/function-lifecycle:<tag> ./demo/setup.sh
```

## Step 2: Create an XR

```shell
kubectl apply -f demo/manifests/xr.yaml
crossplane resource trace app my-app
kubectl get configmap my-app-config -o yaml
```

A provider-kubernetes Object, `config`, created that ConfigMap. The Object is
a managed resource. The `settings` ConfigMap is a plain object, so the
function skips it.

## Step 3: Freeze it

```shell
kubectl annotate app my-app lifecycle.fn.crossplane.io/mode=ObserveOnly
kubectl get objects.kubernetes.m.crossplane.io -l crossplane.io/composite=my-app \
  -o jsonpath='{.items[*].spec.managementPolicies}'
```

The Object now has `["Observe"]`. Change the ConfigMap behind Crossplane's back,
and wait for a poll:

```shell
kubectl patch configmap my-app-config --type merge -p '{"data":{"owner":"someone-else"}}'
sleep 90 && kubectl get configmap my-app-config -o jsonpath='{.data.owner}'
```

It still says `someone-else`: drift isn't reverted while the XR is frozen.
Unfreeze it, and Crossplane reverts the drift on the next poll:

```shell
kubectl annotate app my-app lifecycle.fn.crossplane.io/mode-
```

## Step 4: Delete the XR, keep the resource

Switch to Provision, which never deletes, and wait until the Object has the
new policies:

```shell
kubectl annotate app my-app lifecycle.fn.crossplane.io/mode=Provision --overwrite
kubectl wait objects.kubernetes.m.crossplane.io -l crossplane.io/composite=my-app \
  --for=jsonpath='{.spec.managementPolicies[3]}'=LateInitialize --timeout 2m
```

Then delete the XR. The ConfigMap is still there:

```shell
kubectl delete app my-app
kubectl get configmap my-app-config
```

> **⚠️ Two phases matter.** If you delete before Crossplane applies the new
> policies, the old `["*"]` still includes Delete.

## Step 5: Take it back

```shell
kubectl apply -f demo/manifests/xr.yaml
crossplane resource trace app my-app
```

The new Object adopts the existing ConfigMap.

## Clean up

```shell
kind delete cluster --name contribfest
```

---

## ✅ Done when

The ConfigMap survived `kubectl delete app my-app`.

**Next:** a [curated issue](../CURATED-ISSUES.md). The e2e test you just ran by
hand is one of them.
