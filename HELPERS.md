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

## Common problems

| Symptom | Cause | Fix |
|---|---|---|
| `xpkg init` fails with `failed to read from stdin: EOF` | The `init.sh` prompt | Add `-r` |
| `go test` doesn't compile after `git checkout FETCH_HEAD -- fn_test.go` | Expected: the tests are ahead of the code | That's the lab. Read the compiler error for what's missing. |
| render: `connection refused` / `Unavailable` on `localhost:9443` | Function isn't running | `go run . --insecure --debug` in terminal 1 |
| render shows old behavior | The function wasn't restarted after a code change | `Ctrl-C` and `go run` again. `make -C example test` builds fresh. |
| `bind: address already in use` | An old function is still running | `pkill -f function-lifecycle` or `lsof -ti :9443 \| xargs kill` |
| render is slow or pulls `crossplane/crossplane` | Image not pre-pulled, or no `--crossplane-version` | Pass `--crossplane-version=v2.4.2`. Run `./scripts/check-env.sh`. |
| `Cannot connect to the Docker daemon` | Docker not running. In a Codespace, docker-in-docker is still starting. | Start Docker, or wait 30s in the Codespace. |
| `no space left on device` | Docker disk full | `docker system prune` (ask first, it deletes their images) |
| `unknown field` in input | `request.GetInput` rejects unknown fields | Check the input YAML against `input/v1beta1/input.go`, and rerun `go generate ./...` |
| `-want rsp, +got rsp` diff | A test failure | Lines with `-` are expected, `+` are actual. Usually a message string or a missing condition. |
| `crossplane beta trace: unknown command` | CLI v2.5 renamed it | `crossplane resource trace` |
| golangci-lint not installed | Local laptop | `go run github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.12.0 run ./...` |
| CI `push` job fails with 403 on ghcr.io | Default token can't write packages | Repo Settings → Actions → General → Workflow permissions → Read and write. PR checks don't need it. |
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
