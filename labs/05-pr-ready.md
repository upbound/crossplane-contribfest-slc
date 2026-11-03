# Lab 5: PR-ready

**Objective**: Get the function past the checks a maintainer runs before they
read your code, then open a pull request.

⏱ **10 minutes**

---

## 🎯 Learning Objectives

- Run the same lint CI runs, and fix what it finds
- Write the README and package metadata a user needs
- Sign off commits (DCO) and open a PR

## 📋 Prerequisites

- [ ] Completed Lab 4
- [ ] `gh auth status` shows you're logged in, or use the browser for the PR

## ✅ Verify Lab 4 Completion

```shell
make -C example test   # 7 x PASS
```

---

## Step 1: Lint

CI runs golangci-lint. Run the same version locally:

```shell
golangci-lint run ./...
```

You'll get about 17 findings. Each one is a small lesson:

| Linter | Finding | Fix |
|---|---|---|
| `gochecknoglobals` | `policies is a global variable` | Turn the map into a `switch` inside `Policies()` |
| `modernize` | `ptr(x) can be simplified to new(x)` | Go 1.26 accepts `new("text")`. Delete the `ptr` helper. |
| `revive` | error strings shouldn't end with punctuation | `modeRef %q must be a spec., status., or context. path` (update the test too) |
| `goconst` | `"bucket"` repeated in tests | Table tests repeat literals on purpose. Add `goconst` to the `_test.go` exclusions in `.golangci.yml`. |

```shell
golangci-lint run ./...   # 0 issues
go test ./...
```

> 💡 The warning about `gomodguard` being deprecated comes from the template's
> `.golangci.yml`. That's another upstream fix you could make.

## Step 2: Make it usable

- **`README.md`**: replace the template text. A user needs:
  - what the function does
  - the modes table
  - a pipeline snippet
  - the precedence order
  - recipes such as "freeze during an incident" and "delete the XR, keep the cloud resources"
  - the caveats

  Use the [reference README](https://github.com/upbound/function-lifecycle#readme) for ideas.
- **`package/crossplane.yaml`**: add `meta.crossplane.io/maintainer`, `source`,
  `license`, `description`, and `readme` annotations. Registries and the
  Marketplace show these.
- Delete the template leftovers: `NOTES.txt` and `init.sh`.

## Step 3: Check the package builds (optional, needs Docker)

CI builds the multi-arch runtime image and the package on every pull request,
so you can skip this step. If you have Docker with BuildKit, build it locally:

```shell
docker build . --tag=runtime
crossplane xpkg build -f package --embed-runtime-image=runtime
```

> **⚠️** If `docker build` fails on `RUN --mount` or an empty
> `BUILDPLATFORM`, your Docker has no BuildKit. Colima without `buildx` is
> one example. Skip the step and let CI build it.

## Step 4: Commit and open a PR

Crossplane projects require a [DCO](https://developercertificate.org/) sign-off
on every commit. That's the `-s`:

```shell
git switch -c pr-ready
git add -A
git commit -s -m "docs: make the function PR-ready with README, package metadata, and lint fixes"
```

**Path A: your own repo** (everyone)

```shell
git switch main
gh repo create function-lifecycle --public --source . --push
git switch pr-ready && git push -u origin pr-ready
gh pr create --fill
```

Watch CI run lint, tests, and a multi-arch package build on your PR.

**Path B: upstream** (fast finishers). Pick an issue labelled `contribfest` on
[upbound/function-lifecycle](https://github.com/upbound/function-lifecycle/issues?q=is%3Aissue+is%3Aopen+label%3Acontribfest)
and comment that you're taking it. Then:

```shell
gh repo fork upbound/function-lifecycle --clone && cd function-lifecycle
git switch -c <issue-number>-short-name
# … test first, then code …
make -C example test && golangci-lint run ./...
git commit -s -m "feat: …"
gh pr create --fill
```

Fill in the PR template. "Fixes #N" links the issue.

---

## ✅ Done when

You have a PR URL, and its CI is green or running.

## 🛟 Stuck?

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-05 && git reset --hard FETCH_HEAD
```

**Next:** [Lab 6 (take-home): See it on a cluster](06-e2e-stretch.md), and the
[curated issues](../CURATED-ISSUES.md).
