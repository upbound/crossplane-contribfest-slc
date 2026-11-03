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

- [ ] Docker, kind, helm, and kubectl (the Codespace has all four)
- [ ] About 4 GB of free Docker disk

---

## Step 1: Create the control plane

From the root of this repo:

```shell
./demo/setup.sh
```

This creates a kind cluster with Crossplane 2.4.2, provider-kubernetes, and
three functions: patch-and-transform, lifecycle, and auto-ready. To use your
own build instead of the released package, push it first and then run:

```shell
FN_PACKAGE=ghcr.io/<you>/function-lifecycle:<tag> ./demo/setup.sh
```

## Step 2: Create an XR

```shell
kubectl apply -f demo/manifests/xr.yaml
crossplane resource trace app my-app
kubectl get configmap my-app-config -o yaml   # created through a provider-kubernetes Object
```

The `config` Object is a managed resource. The `settings` ConfigMap is a plain
object, so the function skips it.

## Step 3: Freeze it

```shell
kubectl annotate app my-app lifecycle.fn.crossplane.io/mode=ObserveOnly
kubectl get objects.kubernetes.m.crossplane.io -l crossplane.io/composite=my-app \
  -o jsonpath='{.items[*].spec.managementPolicies}'   # ["Observe"]

# Drift isn't reverted while the XR is frozen
kubectl patch configmap my-app-config --type merge -p '{"data":{"owner":"someone-else"}}'
sleep 90 && kubectl get configmap my-app-config -o jsonpath='{.data.owner}'   # someone-else

# Unfreeze: Crossplane reverts the drift on the next poll
kubectl annotate app my-app lifecycle.fn.crossplane.io/mode-
```

## Step 4: Delete the XR, keep the resource

```shell
kubectl annotate app my-app lifecycle.fn.crossplane.io/mode=Provision --overwrite

# Phase 1: wait until the Object has the new policies
kubectl wait objects.kubernetes.m.crossplane.io -l crossplane.io/composite=my-app \
  --for=jsonpath='{.spec.managementPolicies[3]}'=LateInitialize --timeout 2m

# Phase 2: delete
kubectl delete app my-app
kubectl get configmap my-app-config   # still there
```

> **⚠️ Two phases matter.** If you delete before Crossplane applies the new
> policies, the old `["*"]` still includes Delete.

## Step 5: Take it back

```shell
kubectl apply -f demo/manifests/xr.yaml
crossplane resource trace app my-app   # the new Object adopts the existing ConfigMap
```

## Clean up

```shell
kind delete cluster --name contribfest
```

---

## ✅ Done when

The ConfigMap survived `kubectl delete app my-app`.

**Next:** a [curated issue](../CURATED-ISSUES.md). The e2e test you just ran by
hand is one of them.
