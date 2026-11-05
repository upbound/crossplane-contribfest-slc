# Curated issues

Pick one, comment "I'm taking this", and open a PR. Each issue lists how you'd
prove it works. Write that test first.

## function-lifecycle

These are filed on [upbound/function-lifecycle](https://github.com/upbound/function-lifecycle/issues?q=is%3Aissue+is%3Aopen+label%3Acontribfest)
with the `contribfest` label. Size: **S** fits in the session, **M** is an
evening, **L** needs a design discussion first.

| # | Issue | Size | Done when |
|---|---|---|---|
| 1 | **Raw `policies` escape hatch.** Accept `policies: [Observe, Create]` in the input for sets no mode covers. Reject sets crossplane-runtime doesn't support. | S | Table tests for a supported set, an unsupported set (fatal), and `policies` with `mode` (decide and document precedence) |
| 2 | **`respectExisting`.** Don't overwrite `spec.managementPolicies` that an earlier step set on purpose. | S | A test where the bucket arrives with `["Observe"]` and keeps it |
| 3 | **Propagate to nested XRs.** Copy the mode annotation onto composed XRs, so a whole tree follows one switch. | S | A test where a composed XR gets the annotation and a ConfigMap doesn't |
| 4 | **`debug: true`.** Write the per-resource decisions into the pipeline context under `lifecycle.fn.crossplane.io/decisions`. | S | A test asserting the context key; a render with `-c` shows it |
| 5 | **EnvironmentConfig freeze example.** Add an example using function-environment-configs and an EnvironmentConfig with `managementMode: ObserveOnly`. | S | `./example/test.sh` gets a new PASS line |
| 6 | **Most restrictive wins.** Accept a list of `modeRefs` and pick the most restrictive mode, so a platform freeze beats an XR's own choice. | M | Tests for each pair ordering; README explains the ranking |
| 7 | **Per-resource rules.** Match composed resources by composition-resource-name glob or by kind, and give them their own mode. For example, never delete `backup-*`. | M | Tests for a glob match, a kind match, and no match |
| 8 | **Expiry.** `lifecycle.fn.crossplane.io/expires-at` switches to Deprovision after the time. Set the response TTL so Crossplane calls back right at expiry. | M | Tests with an injected clock, before and after expiry, asserting the TTL |
| 9 | **Change windows.** Outside a cron window, downgrade to `[Observe, Create]`. Requeue at the window boundary. Lab 5's CronOperation already freezes XRs on a schedule, from outside. A window in the input works without Operations, which are alpha. Weigh the two in the issue before you start. | M | Tests with an injected clock inside and outside a window |
| 10 | **Real MR detection.** Replace the `spec.forProvider` heuristic by asking Crossplane for each kind's schema (`CAPABILITY_REQUIRED_SCHEMAS`, Crossplane v2.2+). Fall back to the heuristic on older Crossplane. | M | Tests with and without the capability advertised |
| 11 | **e2e in CI.** Run `./e2e/run.sh` ([Lab 6](labs/06-e2e-stretch.md)) in a GitHub Actions job on kind, for every PR. | M | The job fails on a PR that drops the `operation` capability |
| 12 | **Operation output.** In an Operation, also return the mode and the XRs it changed with `response.SetOutput`, so they show in the Operation's `status.pipeline[].output`. | S | A `TestRunOperation` case that checks the response's `Output` |
| 13 | **WatchOperation example.** Freeze an App as soon as someone labels it `incident: "true"`: a WatchOperation in `example/`, rendered with `crossplane operation render --watched-resource`. | S | A new `example/test.sh` check that renders it |
| 12 | **Investigate a `Pause` mode (`[]`).** Does an empty list survive server-side apply, or does the CRD default `["*"]` come back? Write up what you find. | L | A comment with a reproduction on Crossplane 2.4 |

## Across the ecosystem

Checked on 2026-10-19, and the *new* ones on 2026-11-03. Look again before you
start; some are old.

| Repo | Issue | Why it's a good start |
|---|---|---|
| crossplane/cli | *new*: render's default Development target `localhost:9443` stalls about 10 s per function on some networks | You saw why Lab 1 uses `127.0.0.1`. The render engine dials through gRPC's `dns` resolver; `127.0.0.1`, `[::1]`, and `passthrough:///localhost:9443` are all instant. Default to `127.0.0.1:9443`, or dial with `passthrough`. The Docker engine has the same stall, and there 127.0.0.1 doesn't help: render rewrites the target to `host.docker.internal`, which took 10 s per render on colima, against 0.3 s with `passthrough:///`. |
| crossplane/cli | *new*: render waits a minute, then fails with `signal: killed`, when a Development function isn't listening | Reproduce by rendering with the function stopped. Failing fast with "can't reach function-lifecycle at 127.0.0.1:9443" would save everyone in the room a minute and a guess. |
| crossplane/cli | *new*: `xpkg init` fails with `path outside base dir` when the target path goes through a symlink | Reproduce with `cd /tmp && crossplane xpkg init f function-template-go -d f -r` on macOS. Resolving the base dir with `filepath.EvalSymlinks` is likely the fix. |
| crossplane/cli | *new*: `--crossplane-binary` doesn't look bare names up on `PATH` | It's why the labs say `$(which crossplane-core)`. Small, but ask the maintainers first: it changes a flag's meaning. |
| crossplane-contrib/function-auto-ready | *new*: `go.mod` still says `github.com/crossplane/function-auto-ready` | So `go install github.com/crossplane-contrib/function-auto-ready@latest` fails, and the labs can't run it as a local process. function-patch-and-transform already made this change. |
| crossplane/function-template-go | [#74](https://github.com/crossplane/function-template-go/issues/74) `init.sh` has hard assumptions | You hit it in Lab 1: `package/crossplane.yaml` and `.golangci.yml` aren't renamed, and the module path is always `github.com/crossplane/...`, whatever the function's real home. Stale [PR #75](https://github.com/crossplane/function-template-go/pull/75) covers part of it. |
| crossplane/function-template-go | [#82](https://github.com/crossplane/function-template-go/issues/82) Update package metadata to v1 | Already done: the template uses `meta.pkg.crossplane.io/v1`. Comment with the evidence so it can be closed. Triage counts. |
| crossplane/function-template-go | *new*: `.golangci.yml` isn't ready for golangci-lint 2.13 | You saw the `gomodguard` deprecation warning in Lab 5. 2.13 also replaces `exhaustruct` with `exhaustruct_v5`. The template turns every linter on and disables only the old name, so 2.13 reports 88 `exhaustruct_v5` issues on today's finished function, and editors that bundle 2.13 show them on every test case. 2.12 rejects the new names, so bump CI's golangci-lint and the disable list in the same PR. |
| crossplane/function-template-go | [#48](https://github.com/crossplane/function-template-go/issues/48) Richer examples for reading XR data | Your Lab 3 `lookup` is exactly that |
| crossplane/function-template-typescript | *new*: the template pins `@crossplane-org/function-sdk-typescript` `^0.5.0`; the SDK is at 0.8.0 | A version bump, plus fixing whatever breaks |
| crossplane-contrib/function-go-templating | [#61](https://github.com/crossplane-contrib/function-go-templating/issues/61) render error lacks filename | `good first issue`, a plan was posted 2026-09 |
| crossplane-contrib/function-go-templating | [#40](https://github.com/crossplane-contrib/function-go-templating/issues/40) misleading CompositeConnectionDetails errors | `good first issue` |
| crossplane-contrib/function-go-templating | [#53](https://github.com/crossplane-contrib/function-go-templating/issues/53), [#54](https://github.com/crossplane-contrib/function-go-templating/issues/54) Filesystem source / embed FS | `good first issue` |
| crossplane-contrib/function-environment-configs | [#6](https://github.com/crossplane-contrib/function-environment-configs/issues/6) resolve policy `IfNotPresent` | `good first issue` |
| crossplane/function-template-python | [#88](https://github.com/crossplane/function-template-python/issues/88) post-init hooks | `good first issue`, `help wanted` |

## Your next function

- **Stable secrets.** Generate a password once and keep it stable by reading it
  back from observed state. Nothing on the Marketplace does this today, and it's
  the best way to learn observed vs desired state.
- **function-template-rust.** The official
  [function-sdk-rust](https://github.com/crossplane/function-sdk-rust) is two
  months old and has no template yet.
