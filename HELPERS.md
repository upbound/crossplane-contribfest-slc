# Helper guide

Thanks for helping at the tables. This page has what you need to unblock people
fast.

## Your job

- Get everyone to a green `✅ Done when` before the mission card on screen moves on.
- If someone's more than one lab behind, use the **catch-up** command. Don't
  debug their code while the room moves on. Offer to look at it afterwards.
- From Lab 5 on, help fast finishers pick a `contribfest` issue and get a PR
  open. Review it on the spot if you can.

## Catch-up

Every lab ends at a tag in
[upbound/function-lifecycle](https://github.com/upbound/function-lifecycle).
This works in any repo, including one made with `xpkg init`:

```shell
git fetch https://github.com/upbound/function-lifecycle workshop/lab-0N && git reset --hard FETCH_HEAD
```

| Starting lab | Fetch tag |
|---|---|
| 2 | `workshop/lab-01` |
| 3 | `workshop/lab-02` |
| 4 | `workshop/lab-03` |
| 5 | `workshop/lab-04` |

## Setup

Everyone runs the labs on their own laptop with `./scripts/setup.sh`: Go, the
crossplane CLI, Crossplane itself as the render engine, and
function-patch-and-transform as a local process. Nobody needs Docker until
Lab 6.

- `./scripts/setup.sh --check` checks a laptop without installing anything,
  and ends with a render smoke test.
- No laptop, or setup won't work: pair them up, or have them open the hub repo
  in a GitHub Codespace and run `./scripts/setup.sh` there.

## Common problems

| Symptom | Cause | Fix |
|---|---|---|
| `crossplane-core isn't on your PATH`, or `command not found: crossplane` after setup | `~/.local/bin` isn't on `PATH` | Add `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc` or `~/.bashrc`, then open a new terminal |
| `xpkg init` fails with `failed to read from stdin: EOF` | The `init.sh` prompt | Add `-r` |
| `xpkg init` fails with `path outside base dir` | The path goes through a symlink, such as `/tmp` on macOS | Run it under `~` |
| `go test` fails right after `git checkout FETCH_HEAD -- fn_test.go` | Expected: the tests are ahead of the code | That's the lab. The `-want`/`+got` diff shows what's missing. |
| render: `--crossplane-binary: stat …/crossplane-core: no such file or directory` | The flag takes a path, not a command name | `--crossplane-binary=$(which crossplane-core)`, or use `make -C example render` |
| render: `Cannot connect to the Docker daemon` | `--crossplane-binary` is missing, so render fell back to Docker | Add `--crossplane-binary=$(which crossplane-core)` |
| render takes 10+ seconds | `functions.yaml` targets `localhost`, which resolves slowly on some networks | Set `render.crossplane.io/runtime-development-target: 127.0.0.1:9443` (Lab 1, Step 3) |
| render: `connection refused` / `Unavailable` on `127.0.0.1:9443` | The function isn't running | `go run . --insecure --debug` in terminal 1 |
| render: `connection refused` on `127.0.0.1:9444` | function-patch-and-transform isn't running | `make -C example render` starts it. For hand renders, run `make -C example serve`. |
| render shows old behavior | The function wasn't restarted after a code change | `Ctrl-C` and `go run` again. `make -C example test` builds fresh. |
| `make test`: `Something is already listening on port 9443` | `go run` is still running in terminal 1 | `Ctrl-C` it, then `make -C example test` again |
| `bind: address already in use` | An old function is still running | `lsof -ti :9443 \| xargs kill`. For port 9444: `make -C example stop`. |
| macOS asks whether to accept incoming network connections | The firewall sees a new binary after each `go run` | Click Allow. Or run `go run . --insecure --debug --address=127.0.0.1:9443`, which listens on loopback only. |
| `no space left on device` | Go's build cache is about 2 GB | `go clean -cache` frees it. The next build is slower. |
| Lab 5 `docker build` fails on `RUN --mount` or `BUILDPLATFORM` | Docker without BuildKit, for example Colima without `buildx` | Skip it. CI builds the package. |
| `unknown field` in input | `request.GetInput` rejects unknown fields | Check the input YAML against `input/v1beta1/input.go`, and rerun `go generate ./...` |
| `-want rsp, +got rsp` diff | A test failure | Lines with `-` are expected, `+` are actual. Usually a message string or a missing condition. |
| `crossplane beta trace: unknown command` | CLI v2.5 renamed it | `crossplane resource trace` |
| golangci-lint not installed | Local laptop | `go run github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.12.0 run ./...` |
| CI `push` job fails with 403 on ghcr.io | Default token can't write packages | Repo Settings → Actions → General → Workflow permissions → Read and write. PR checks don't need it. |
| CI `push` job fails with `DENIED` on the second architecture, on the repo's very first push | ghcr.io creates the package with the first architecture, but the workflow can't write to it yet | Re-run the failed job (`gh run rerun <id> --failed`). It passed on the re-run for upbound/function-lifecycle. PR checks don't run this job. |
| PR has a DCO failure | Commit isn't signed off | `git commit --amend -s --no-edit && git push -f` |

## Talking points when someone asks…

- **"Why not just patch `managementPolicies` in every composition?"** We have
  five copies in our own repos, each with its own parameter name and slightly
  different behavior. There's no single switch an operator can flip to freeze
  or orphan an XR.
- **"Why not in core?"** It's been discussed. An Orphan policy was added and
  then reverted (crossplane/crossplane#6694, crossplane-runtime#931), and draft
  PR crossplane/crossplane#7367 explores an XR-level switch. How a whole
  composition's resources behave is each platform team's choice, so it fits
  the pipeline. A function keeps core small and lets each composition opt in.
- **"What if the provider doesn't support management policies?"** Upjet
  providers and provider-kubernetes enable them by default. Classic
  crossplane-contrib/provider-aws doesn't. The MR then errors with "set to a
  non-default value but the feature is not enabled".
- **"Is `spec.forProvider` a reliable MR check?"** It's a heuristic. Asking
  Crossplane for the resource schema (`CAPABILITY_REQUIRED_SCHEMAS`, v2.2+) is
  better, and that's a curated issue.
