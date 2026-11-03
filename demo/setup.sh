#!/usr/bin/env bash
# Creates a kind cluster with Crossplane, provider-kubernetes, and the three
# functions the demo pipeline uses.
#
#   ./demo/setup.sh
#   FN_PACKAGE=ghcr.io/<you>/function-lifecycle:<tag> ./demo/setup.sh   # your build
set -euo pipefail

CLUSTER=${CLUSTER:-contribfest}
CROSSPLANE_VERSION=${CROSSPLANE_VERSION:-2.4.3}
FN_PACKAGE=${FN_PACKAGE:-xpkg.upbound.io/upbound/function-lifecycle:v0.1.0}
DIR=$(cd "$(dirname "$0")" && pwd)

kind get clusters 2>/dev/null | grep -qx "$CLUSTER" || kind create cluster --name "$CLUSTER" --wait 2m

helm repo add crossplane-stable https://charts.crossplane.io/stable --force-update >/dev/null
helm upgrade --install crossplane crossplane-stable/crossplane --version "$CROSSPLANE_VERSION" \
  --namespace crossplane-system --create-namespace --wait

kubectl apply -f "$DIR/manifests/provider.yaml"
sed "s#FN_PACKAGE#$FN_PACKAGE#" "$DIR/manifests/functions.yaml" | kubectl apply -f -
kubectl wait providers.pkg.crossplane.io --all --for condition=Healthy --timeout 5m
kubectl wait functions.pkg.crossplane.io --all --for condition=Healthy --timeout 5m

kubectl apply -f "$DIR/manifests/providerconfig.yaml" -f "$DIR/manifests/definition.yaml"
kubectl wait xrd apps.example.crossplane.io --for condition=Established --timeout 2m
kubectl apply -f "$DIR/manifests/composition.yaml"

echo "Ready. Next: kubectl apply -f $DIR/manifests/xr.yaml"
