# Lab 5: PR-ready

**Objective**: Get the function past the checks a maintainer runs before they
read your code, then open a pull request.

⏱ **10 minutes**

---

## 🎯 Learning Objectives

- Run the same lint CI runs, and fix what it finds
- Know what README and package metadata a user needs
- Sign off commits (DCO), open a PR, and fill in its template

## 📋 Prerequisites

- [ ] Completed Lab 4, and `make serve` stopped
- [ ] A terminal in `~/function-lifecycle`. Every command in this lab runs there.
- [ ] `gh auth status` shows you're logged in, or use the browser for the PR

## ✅ Verify Lab 4 Completion

```shell
make -C example test
```

It prints `PASS` for all seven examples.

---

## Step 1: Lint

CI runs golangci-lint. Run the same version locally, then let Go fix what it
can:

```shell
golangci-lint run ./...
go fix ./...
```

Lint reports 17 issues. `go fix` applies the 12 `modernize` fixes: Go 1.26
accepts `new("text")`, so every `ptr("text")` in `fn_test.go` becomes
`new("text")`.

Now delete the `ptr` helper in `fn_test.go`: the `func ptr` line and the
comment lines above it, from `// ptr returns a pointer to the supplied value.`
down. `go fix` added `//go:fix inline` to that comment. Until the helper is
gone, lint also reports it as `unused` and flags the directive.

The other five are yours:

| Linter | Where | Fix |
|---|---|---|
| `gochecknoglobals` | `mode.go`: `policies is a global variable` | Turn the map into a `switch` inside `Policies()`. |
| `revive` | `fn.go`: an error string ends with punctuation | Reword the `modeRef` error to `modeRef %q must be a spec., status., or context. path`, and update the matching test. |
| `goconst` | `fn_test.go`: `bucket`, `LifecycleMode`, and `ObserveOnly` repeated | Table tests repeat literals on purpose. In `.golangci.yml`, add `goconst` to the linters excluded for `_test(ing)?\.go`, the list that starts with `containedctx`. |

```shell
golangci-lint run ./...
go test ./...
```

Lint reports `0 issues`, and the tests pass.

> 💡 The warning about `gomodguard` being deprecated comes from the template's
> `.golangci.yml`. That's another upstream fix you could make.

## Step 2: README and package metadata

Users read the README. Registries and the Marketplace show the
`meta.crossplane.io` annotations in `package/crossplane.yaml`. A good README
takes longer than this lab, so start from the reference and make it yours.
These commands also delete two template leftovers, `NOTES.txt` and `init.sh`:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-05
git checkout FETCH_HEAD -- README.md package/crossplane.yaml
rm NOTES.txt init.sh
```

Read both. The README covers what a user needs: what the function does, the
modes, a pipeline snippet, the precedence order, recipes such as "delete the
XR, keep the cloud resources", and the caveats. Change anything you'd say
differently. Writing one from scratch is a good take-home.

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
git commit -s -m "feat: add lifecycle modes per XR"
```

`main` still holds only the scaffold from Lab 1, so your branch carries the
whole function.

**Path A: your own repo** (everyone)

```shell
git switch main
gh repo create function-lifecycle-lab --public --source . --push
git switch pr-ready && git push -u origin pr-ready
gh pr create --web
```

`--web` opens the pull request form in your browser, filled in with the
repo's PR template. Work through its checklist, then create the PR. Watch CI
run lint, tests, and a multi-arch package build on it.

> 💡 Pushing `main` also starts CI there. On a new repo, its `push` job
> usually fails with a 403: it publishes the package to ghcr.io, and new repos
> don't give workflows permission to write packages. Your PR doesn't run that
> job, so ignore it.

**Path B: upstream** (fast finishers). Pick an issue labelled `contribfest` on
[upbound/function-lifecycle](https://github.com/upbound/function-lifecycle/issues?q=is%3Aissue+is%3Aopen+label%3Acontribfest)
and comment that you're taking it. Then work in a fresh fork, next to your
lab copy:

```shell
mkdir -p ~/upstream && cd ~/upstream
gh repo fork upbound/function-lifecycle --clone && cd function-lifecycle
git switch -c <issue-number>-short-name
```

Write the test first, then the code. Then:

```shell
make -C example test && golangci-lint run ./...
git add -A && git commit -s -m "feat: <what it does>"
git push -u origin HEAD
gh pr create --web
```

Fill in the PR template. "Fixes #N" links the issue.

---

## ✅ Done when

You have a PR URL, and its CI is green or running.

When you're done for the day, stop function-patch-and-transform, which
`make` left running:

```shell
make -C ~/function-lifecycle/example stop
```

## 🛟 Stuck?

Jump to the finished Lab 5:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-05 && git read-tree -u --reset FETCH_HEAD
```

This replaces your files with the end of Lab 5 and leaves `main` at your
scaffold commit. Then do Step 4 as written.

**Next:** [Lab 6 (take-home): See it on a cluster](06-e2e-stretch.md), and the
[curated issues](../CURATED-ISSUES.md).
