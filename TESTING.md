# Manual test plan

Goal: by **Nov 10**, show that someone with only Go and git can get from this
repo to an open PR in 80 minutes, on macOS and Linux, with no Docker, and that
the session survives slow conference Wi-Fi.

## What's already verified, and what isn't

Checked on 2026-11-03 on an arm64 Mac (Go 1.27.1, zsh, Docker deliberately
unreachable):

- Every `workshop/lab-0N` tag builds and passes `go test`, and its renders give
  the expected output.
- Labs 1–5 walked through as an attendee would. The lab pages' commands were
  used as written, the reference repo was a local path, and each lab's code was
  taken from its tag.
- `scripts/setup.sh` from cold caches: done in 72 seconds (about 235 MB downloaded, 3 GB of disk), smoke test
  passes, and `--check` passes three times in a row.
- golangci-lint finds 17 issues on the Lab 4 code and 0 on Lab 5.

On 2026-11-04, two emulated first-time attendees ran the start slide and Labs
1–5 in a sandbox laptop (own HOME, cold caches, stock make). They wrote the
code from the lab pages, without the solution. The first run found 24 issues
and the second 10; all are fixed. In the second run:
- Every lab was completed from the instructions alone.
- Every catch-up kept `main` at the scaffold, and Lab 5's commit worked after one.
- Nothing downloaded with `GOPROXY=off` after setup.

The `gh` steps of Lab 5 weren't run.

These can't be checked without you:

- Clean machines: Linux, WSL2, Intel Mac, and a laptop that has never built Go.
- Anything that needs GitHub: catch-up from the real URL, Lab 5 PRs and CI,
  and setup warming the function-lifecycle modules.
- A newcomer's pace against the time boxes.
- Lab 6 and the demo on kind.
- How the deck renders on the venue projector.
- Conference-like network conditions.

## 0. Unblock first

Sections 3–6 need these:

- [x] Create `upbound/function-lifecycle` and this hub repo, and push `main`
      and the workshop tags (2026-11-03, both private)
- [ ] Make both repos public. Org members can't create public repos in
      `upbound`, so an org owner has to change the visibility. Until then,
      give testers access.
- [x] Registry: `ghcr.io/upbound/function-lifecycle`, for vendor neutrality
      (2026-11-04). CI pushes there; the examples and `demo/setup.sh` say so.
- [ ] Release v0.1.0: run CI with `version: v0.1.0`, then make the ghcr.io
      package public. It's private like the repo, so a cluster can't pull it.
- [ ] File the curated issues on function-lifecycle with the `contribfest`
      label, plus a pinned tracking issue

## 1. Setup on clean machines

Have a different person run each machine if you can. Start from "Go and git
installed, nothing else", then follow [PREREQUISITES.md](PREREQUISITES.md)
word for word.

| Machine | Who | Notes |
|---|---|---|
| macOS arm64, zsh, no Docker | | The most common attendee laptop |
| macOS Intel | | `darwin_amd64` downloads |
| Linux amd64 (Ubuntu or Fedora), bash | | `sha256sum` path; distro Go may set `GOTOOLCHAIN=local` |
| Windows 11 + WSL2 Ubuntu | | |
| GitHub Codespace on this repo, default image | | The fallback in PREREQUISITES |

For each one:

- [ ] Run `./scripts/setup.sh`. Time it, note any `✘` or `!`, and check its
      summary for the Go version and download speed.
- [ ] Follow the `PATH` hint if it shows one, open a new terminal, and run
      `./scripts/setup.sh --check`. It ends with **You're ready for the labs.**
- [ ] Run it a second time. It takes seconds and installs nothing.
- [ ] `which crossplane crossplane-core function-patch-and-transform golangci-lint`
      all resolve.

Edge cases, once each, on any machine:

- [ ] Go 1.25 with `GOTOOLCHAIN=auto` (the default): setup warns, and Go
      downloads 1.26 by itself.
- [ ] An old crossplane CLI earlier on `PATH`: setup installs v2.5 and warns
      that the old one comes first.
- [ ] A golangci-lint built with an older Go earlier on `PATH` (Homebrew's,
      or an old release binary): setup builds one with your Go and warns.
- [ ] `BIN_DIR=/some/dir ./scripts/setup.sh` installs there.

## 2. Offline after setup

The labs should only need the network for `xpkg init`, which clones the
template, and for `git fetch`.

- [ ] Run Lab 1, Step 1, then turn Wi-Fi off.
- [ ] Do the rest of Lab 1, and Labs 2–4 using the catch-up tags you fetched
      beforehand. `go test`, `go generate`, `go mod tidy`, the renders,
      `./example/test.sh`, and `golangci-lint` must all work.
- [ ] Note anything that hangs or downloads.

## 3. Timed attendee walkthrough

Best with a colleague who hasn't seen the labs, and you only watching. Use the
lab pages, not this file. Record times against the time boxes.

| Lab | Box | Actual | Done-when met | Notes |
|---|---|---|---|---|
| 1. Scaffold | 8 min | | | |
| 2. Core logic | 15 min | | | |
| 3. Generalize | 10 min | | | |
| 4. Debug | 8 min | | | |
| 5. PR-ready | 10 min | | | |

Things to watch:

- [ ] **Lab 1**:
  - Do they find the line to add to `example/functions.yaml`?
  - Render takes about a second, not 10+.
  - Terminal 1 logs `Running function`.
- [ ] **Lab 2**:
  - `go test` fails right after the checkout, as the page says.
  - They start function-patch-and-transform in terminal 3, and the render
    calls both functions.
  - `xr-invalid.yaml` fails closed.
- [ ] **Lab 3**:
  - `go generate` writes `package/input/lifecycle.fn.crossplane.io_inputs.yaml`.
  - `go mod tidy` works.
  - The spec render shows `ObserveOnly`; the context render shows `Deprovision`.
- [ ] **Lab 4**:
  - `./example/test.sh` gives 7 × PASS after the restart.
  - With a function stopped, it says which port has nothing listening.
  - The hand renders with `-r -x` and `-c` work.
- [ ] **Lab 5**:
  - golangci-lint reports 17 findings, then 0 after the fixes.
  - Path A: `gh repo create` and `gh pr create` work, and CI starts. Note how
    long the multi-arch build takes.
- [ ] **Lab 5, Path B**: fork upstream, branch, PR against a real `contribfest`
      issue, then close the PR.
- [ ] Where did they hesitate or misread? Fix the page, not the person.

## 4. Catch-up from every lab

From a directory where the previous lab went wrong (leave a compile error in
`fn.go`), run each lab's 🛟 command against the real GitHub URL:

- [ ] `workshop/lab-01`. Also try it right after a failed `xpkg init`, with
      no repo yet: the command runs `git init` itself.
- [ ] `workshop/lab-02`, `lab-03`, `lab-04`, `lab-05`: after each, run
      `go test ./...` and that lab's done-when command. `git log` still shows
      only the scaffold commit.
- [ ] After the `workshop/lab-05` catch-up, Lab 5 Step 4 commits the whole
      function on `pr-ready`.
- [ ] Labs 2–4, Step 1 (`git checkout FETCH_HEAD -- fn_test.go example/`) on
      top of a clean previous tag.

## 5. Things that will go wrong in the room

Reproduce each [HELPERS.md](HELPERS.md) row once, so you and the helpers
recognize the message and know the fix works:

- [ ] `localhost:9443` as the target: render takes 10+ seconds, or doesn't
      on your network. Note which.
- [ ] Render without `--crossplane-binary`: the Docker error.
- [ ] `--crossplane-binary=crossplane-core` without `$(which …)`: the `stat`
      error.
- [ ] `xpkg init` under `/tmp` on macOS: `path outside base dir`.
- [ ] `~/.local/bin` not on `PATH`.
- [ ] Port 9443 or 9444 already in use: `bind: address already in use`.
- [ ] **macOS firewall**: with the firewall on (System Settings → Network →
      Firewall), does `go run . --insecure --debug` trigger the "accept
      incoming connections" prompt? Does `--address=127.0.0.1:9443` avoid it?
      Does clicking Deny still let render connect? Update the HELPERS row
      with what you find.

## 6. Demo and Lab 6 on kind (presenter laptop)

- [ ] `./demo/setup.sh` from scratch. Time it, since it pulls images.
- [ ] Run the demo slide's script end to end: freeze, then orphan, then adopt.
      Aim for under 5 minutes.
- [ ] Run Lab 6 as written, then Full mode: deleting the XR deletes the
      ConfigMap.
- [ ] Record the demo video as the Wi-Fi fallback.

## 7. Deck

- [ ] Look through every slide in the Slides artifact. Check that the code on
      the `lab1` and `lab5` cards fits, and the logo on the cover.
- [ ] Scan the `start` QR code from the back of a room. Add the `thanks`
      feedback QR code once the sched link exists, and scan that too.
- [ ] Export the PDF for sched.
- [ ] Rehearse the talk segments with a timer. The target is about 12 minutes
      of slides before Lab 1, and the demo after Lab 5 in under 5.

## 8. The day before (Nov 10)

- [ ] **Template drift**: `xpkg init` a fresh function and diff it against
      `workshop/lab-01`. Only `go.mod`, `go.sum`, and the two comment lines in
      `example/functions.yaml` should differ. A change to `fn.go`, `main.go`,
      `init.sh`, or `example/` breaks Lab 1 or 2.
- [ ] New releases since Nov 3? Check the crossplane CLI, Crossplane core,
      function-patch-and-transform, and Go. The pins hold, but read the
      release notes for `render` changes.
- [ ] The ecosystem issues in CURATED-ISSUES are still open.
- [ ] Every helper ran `./scripts/setup.sh --check` and has read HELPERS.md.
- [ ] The demo cluster is up, and the video is on the laptop.

## Results

| Date | Machine | Go | Setup time | ✘ / ! | Lab 1–5 times | Problems found |
|---|---|---|---|---|---|---|
| 2026-11-03 | macOS arm64, zsh, no Docker | 1.27.1 | ~1 min, cold | — | scripted | localhost costs 10 s per function; `--crossplane-binary` needs a path; `xpkg init` fails through symlinks; golangci-lint 2.12.0 release binary panics on Go 1.27. All fixed or worked around. |
| 2026-11-04 | sandbox laptop, run 1 | 1.27.1 | 1:17 cold | PATH ✘ | est. 7–9 / 18–22 / 12–15 / 10–13 / 20–25 min | Catch-up broke Lab 5's PR; Lab 2 outline dropped the `Function` type; working directory unclear between terminals; Lab 5 far over its box; and 20 smaller. Fixed. |
| 2026-11-04 | sandbox laptop, run 2, offline after setup | 1.27.1 | 1:23 cold | PATH ✘ (no TTY) | est. 6–8 / 12–18 / 12–15 / 8–11 / 12–15 min | Pasted `# comments` break stock macOS zsh; `setup.sh` exited 1 on success; a stopped function makes render hang 60 s. Fixed. |
