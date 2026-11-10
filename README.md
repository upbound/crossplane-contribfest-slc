# Crossplane ContribFest: Start Your Journey to Crossplane Function Maintainer

**KubeCon + CloudNativeCon North America 2026** · Salt Lake City · Nov 11,
11:00–12:20 · Salt Palace, Level 2, 255 D

**Set up before the session.** Install Go 1.26+, then:

```shell
git clone https://github.com/upbound/crossplane-contribfest-slc
cd crossplane-contribfest-slc
./scripts/setup.sh
```

It takes about five minutes, needs no Docker, and ends with **You're ready for
the labs.** Run it at your hotel, or as soon as you sit down: the first run
downloads about 250 MB, and the whole room shares one Wi-Fi. A rerun takes
seconds. If you have Docker, kind, kubectl, and helm, run
`./scripts/setup.sh --e2e` instead: it also creates the cluster for Lab 6.
Details, and what to do without a laptop: [PREREQUISITES.md](PREREQUISITES.md).

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
| [5. Operations, then PR-ready](labs/05-pr-ready.md) | Run the function as an Operation, `go fix`, and a signed-off commit | 10 min |
| [6. Local e2e](labs/06-e2e-stretch.md) | Test your build on a kind cluster, get the e2e test green, and commit it with your function | 10 min |

Fell behind? Every lab ends at a tag. From `~/function-lifecycle`, jump to it with:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-0N && git read-tree -u --reset FETCH_HEAD
```

It replaces your files with the end of that lab, and doesn't touch your git
history. Lab 1's page has its own command, for when the scaffold itself went
wrong.

## Keep going

- [**Curated issues**](CURATED-ISSUES.md) in function-lifecycle and across the
  function ecosystem
- [Crossplane Slack](https://slack.crossplane.io)
- [Community meetings](https://github.com/crossplane/crossplane#get-involved)
- [Writing a composition function in Go](https://docs.crossplane.io/latest/guides/write-a-composition-function-in-go/)
- How to contribute: [CONTRIBUTING.md](https://github.com/crossplane/crossplane/blob/main/CONTRIBUTING.md),
  [AI_POLICY.md](https://github.com/crossplane/crossplane/blob/main/AI_POLICY.md),
  and [becoming a maintainer](https://github.com/crossplane/crossplane/blob/main/GOVERNANCE.md#becoming-a-maintainer)

## For helpers

See [HELPERS.md](HELPERS.md).

## License

[Apache 2.0](LICENSE).
