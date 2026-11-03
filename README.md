# Crossplane ContribFest: Start Your Journey to Crossplane Function Maintainer

**KubeCon + CloudNativeCon North America 2026** · Salt Lake City · Nov 11,
11:00–12:20 · Salt Palace, Level 2, 255 D

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/upbound/crossplane-contribfest-slc)

**Start your Codespace now.** It takes about a minute, and everything is
preinstalled. Working locally instead? See [PREREQUISITES.md](PREREQUISITES.md).

---

## What we're building

[**function-lifecycle**](https://github.com/upbound/function-lifecycle) is a
composition function that sets the lifecycle mode of every managed resource an
XR composes, in one place:

```yaml
metadata:
  annotations:
    lifecycle.fn.crossplane.io/mode: Provision   # delete the XR, keep the cloud resources
```

| Mode | `managementPolicies` |
|---|---|
| `Full` | `["*"]` |
| `Provision` | `[Observe, Create, Update, LateInitialize]` |
| `ObserveOnly` | `[Observe]` |
| `Deprovision` | `[Observe, Create, Delete]` |

Crossplane v2 namespaced managed resources have no `deletionPolicy`, so
management policies are how you import, freeze, migrate, or orphan resources.
Today every composition patches them by hand.

## Labs

| Lab | You'll | Time |
|---|---|---|
| [1. Scaffold](labs/01-scaffold.md) | Go from an empty directory to a function answering `crossplane composition render` | 8 min |
| [2. Core logic](labs/02-core-logic.md) | Read the mode, set policies on composed MRs, and make the tests pass | 15 min |
| [3. Generalize](labs/03-generalize-input.md) | Add an input API: the mode from the XR spec, status, or pipeline context | 10 min |
| [4. Debug](labs/04-pipeline-debug.md) | Add results, conditions, and a render test harness, and look inside the pipeline | 8 min |
| [5. PR-ready](labs/05-pr-ready.md) | Lint, docs, package, DCO, and open the PR | 10 min |
| [6. On a cluster](labs/06-e2e-stretch.md) *(take-home)* | Freeze, orphan, and re-adopt on kind | 20 min |

Fell behind? Every lab ends at a tag. Jump to it with:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-0N && git reset --hard FETCH_HEAD
```

## Keep going

- [**Curated issues**](CURATED-ISSUES.md) in function-lifecycle and across the
  function ecosystem
- [Crossplane Slack](https://slack.crossplane.io), `#dev`
- [Community meetings](https://github.com/crossplane/crossplane#get-involved)
- [Writing a composition function in Go](https://docs.crossplane.io/latest/guides/write-a-composition-function-in-go/)
- How to contribute: [CONTRIBUTING.md](https://github.com/crossplane/crossplane/blob/main/CONTRIBUTING.md),
  [AI_POLICY.md](https://github.com/crossplane/crossplane/blob/main/AI_POLICY.md),
  and [becoming a maintainer](https://github.com/crossplane/crossplane/blob/main/GOVERNANCE.md#becoming-a-maintainer)

## For helpers

See [HELPERS.md](HELPERS.md).
