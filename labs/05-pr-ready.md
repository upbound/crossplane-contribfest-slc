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

- [ ] Completed Lab 4
- [ ] Your function running in terminal 1, and function-patch-and-transform in
  terminal 3 (Lab 2, Step 1)
- [ ] A terminal in `~/function-lifecycle`. Every command in this lab runs there.
- [ ] `gh auth status` shows you're logged in, or use the browser for the PR

## ✅ Verify Lab 4 Completion

```shell
./example/test.sh
```

It prints `PASS` for all seven examples.

---

## Step 1: Lint

CI runs golangci-lint. Run the same version locally:

```shell
golangci-lint run ./...
```

Each issue reads `file:line:column: message (linter)`. Ignore the two
`level=warning` lines about `gomodguard` at the top: see the tip at the end of
this step. The output ends with a count per linter:

```text
17 issues:
* gochecknoglobals: 1
* goconst: 3
* modernize: 12
* revive: 1
```

Four fixes get that to zero. Run `golangci-lint run ./...` after each one to
check the count.

### Fix 1: let Go fix the 12 `modernize` issues

```shell
go fix ./...
```

Go 1.26 accepts `new("text")`, so `go fix` replaces every `ptr("text")` in
`fn_test.go` with it. That leaves the `ptr` helper unused, so lint now reports
two new issues on it. Delete these four lines from `fn_test.go`, around line
54:

```go
// ptr returns a pointer to the supplied value.
//
//go:fix inline
func ptr[T any](v T) *T { return new(v) }
```

Lint now reports **5 issues**.

### Fix 2: `mode.go` has a global variable (`gochecknoglobals`)

Any code in the package can change a package-level variable, so the linter
doesn't allow them. In `mode.go`, replace everything from `var policies` to the
end of the file with a `switch`:

```go
// Policies returns the management policies for the mode. Every set is one of
// the combinations crossplane-runtime supports.
func (m Mode) Policies() ([]string, error) {
	switch m {
	case ModeFull:
		return []string{"*"}, nil
	case ModeProvision:
		return []string{"Observe", "Create", "Update", "LateInitialize"}, nil
	case ModeObserveOnly:
		return []string{"Observe"}, nil
	case ModeDeprovision:
		return []string{"Observe", "Create", "Delete"}, nil
	default:
		return nil, errors.Errorf("unknown mode %q: must be one of Full, Provision, ObserveOnly, Deprovision", m)
	}
}
```

Lint now reports **4 issues**.

### Fix 3: `fn.go` has an error string that ends with punctuation (`revive`)

Go wraps error strings into longer messages, so they shouldn't end with
punctuation. The `modeRef` error in `lookup` ends with `context.`. This finds
it, and the test that checks the exact message:

```shell
grep -n 'must start with' fn.go fn_test.go
```

In both files, change `must start with spec., status., or context.` to
`must be a spec., status., or context. path`. In `fn.go` the line becomes:

```go
		return "", errors.Errorf("modeRef %q must be a spec., status., or context. path", ref)
```

In `fn_test.go`:

```go
							Message:  `modeRef "metadata.name" must be a spec., status., or context. path`,
```

Lint now reports **3 issues**.

### Fix 4: `fn_test.go` repeats strings (`goconst`)

Table tests repeat values such as `bucket` on purpose, so turn `goconst` off
for test files instead. In `.golangci.yml`, find the exclusion rule that ends
with `path: _test(ing)?\.go`, about 155 lines down. Add `goconst` to its list
of linters, after `gocognit`:

```yaml
      - linters:
          - containedctx
          - errcheck
          - forcetypeassert
          - gochecknoglobals
          - gochecknoinits
          - gocognit
          - goconst            # add this
          - gosec
          - scopelint
          - unparam
          - embeddedstructfieldcheck
        path: _test(ing)?\.go
```

### Check

```shell
golangci-lint run ./...
go test -v ./...
```

Lint reports `0 issues`, and the tests pass.

> 💡 The warning about `gomodguard` being deprecated comes from the template's
> `.golangci.yml`. That's another upstream fix you could make.

> 🛟 Short on time? This copies all four fixes from the reference:
>
> ```shell
> git fetch https://github.com/upbound/function-lifecycle workshop/lab-05
> git checkout FETCH_HEAD -- fn.go fn_test.go mode.go .golangci.yml
> ```

## Step 2: README and package metadata

Users read the README. Registries and the Marketplace show the
`meta.crossplane.io` annotations in `package/crossplane.yaml`. A good README
takes longer than this lab, so start from the reference and make it yours.
These commands also delete two template leftovers, `NOTES.txt` and `init.sh`:

```shell
cd ~/function-lifecycle
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

Write the test first, then the code. If you change `example/`, stop the
function in terminal 1, run the fork's instead, and run `./example/test.sh`.
Then:

```shell
go test -v ./... && golangci-lint run ./...
git add -A && git commit -s -m "feat: <what it does>"
git push -u origin HEAD
gh pr create --web
```

Fill in the PR template. "Fixes #N" links the issue.

---

## ✅ Done when

You have a PR URL, and its CI is green or running.

When you're done for the day, stop both functions: `Ctrl-C` in terminals 1
and 3.

## 🛟 Stuck?

Jump to the finished Lab 5:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-05 && git read-tree -u --reset FETCH_HEAD
```

This replaces your files with the end of Lab 5 and leaves `main` at your
scaffold commit. Then do Step 4 as written.

**Next:** [Lab 6 (take-home): See it on a cluster](06-e2e-stretch.md), and the
[curated issues](../CURATED-ISSUES.md).
