# Before the session

Labs 1–5 run on your laptop with no Docker and no cluster. Lab 6 runs a small
kind cluster, so if you have Docker, set that up before the session too
([step 3](#3-for-lab-6-create-the-cluster-needs-docker)). Setup takes about five
minutes. Please do it **before** the session, so the room doesn't
download 250 MB each over the conference Wi-Fi at the same time.

## 1. Install Go and git

| Tool | Version | Install |
|---|---|---|
| Go | 1.26+ | <https://go.dev/dl>, or `brew install go` |
| git | any, with a name and email set | You probably have it. If not: `git config --global user.name "Your Name"` and `git config --global user.email you@example.com` |

On Windows, use [WSL2](https://learn.microsoft.com/windows/wsl/install) and do
everything inside it.

## 2. Run the setup script

```shell
git clone https://github.com/upbound/crossplane-contribfest-slc
cd crossplane-contribfest-slc
./scripts/setup.sh
```

It installs these into `~/.local/bin` without sudo, and skips any you already
have:

| Tool | What it's for |
|---|---|
| `crossplane` CLI v2.5 | `xpkg init` and `composition render` |
| `crossplane-core` v2.4.3 | Crossplane itself. `render --crossplane-binary` runs it as the render engine, instead of in Docker. |
| `function-patch-and-transform` v0.11.2 | The first step of the lab pipeline, run as a local process |
| `golangci-lint` v2.12.0 | Lab 5. Built with your Go: a binary built with an older Go panics on newer code. |

Then it renders a test composition, and builds function-template-go and
function-lifecycle once, so Go's caches hold every module the labs use. After
that the labs work offline.

If `~/.local/bin` isn't on your `PATH`, it offers to add it to your shell's
startup file. Then open a new terminal, or run the `export` line it prints.

You're done when it prints **You're ready for the labs.**

It downloads about 250 MB and uses about 3 GB of disk, mostly Go's build
cache. To install somewhere else, run `BIN_DIR=/some/dir ./scripts/setup.sh`.

## 3. For Lab 6: create the cluster (needs Docker)

Lab 6 tests your function on a local kind cluster. With Docker running, and
kind, kubectl, and helm installed, run:

```shell
./scripts/setup.sh --e2e
```

It does everything step 2 does, then creates a kind cluster called
`lifecycle-e2e` with the reference function's `e2e/cluster.sh`, and runs its
e2e test once. That pulls about 1.5 GB of images and leaves the cluster
running, ready for Lab 6. It takes about 5 minutes, and points
`kubectl` at the new cluster.

No Docker? That's fine. Pair up for Lab 6, or follow it on the projector.

## Optional

| Tool | Needed for |
|---|---|
| A GitHub account | Contributing after the session. The labs don't open PRs. |
| Docker, kind, kubectl, helm | Lab 6, see [step 3](#3-for-lab-6-create-the-cluster-needs-docker) |

## No laptop, or setup failed?

- **Pair up.** The labs work well with two people at one keyboard.
- **Use a GitHub Codespace.** Open this repo in a Codespace (**Code →
  Codespaces → Create**) and run `./scripts/setup.sh` there. The default image
  has Go and git. Personal GitHub accounts include free Codespaces hours each
  month.

> **⚠️ Old Crossplane CLI?** The CLI now lives in
> [crossplane/cli](https://github.com/crossplane/cli), and v2.5 renamed some
> commands, for example `crossplane beta trace` became
> `crossplane resource trace`. `setup.sh` installs v2.5 if yours is older.
