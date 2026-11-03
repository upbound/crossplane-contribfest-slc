# Before the session

Everything runs on your laptop, with no Docker and no cluster. Setup takes
about five minutes. Please do it **before** the session, so the room doesn't
download 250 MB each over the conference Wi-Fi at the same time.

## 1. Install Go and git

| Tool | Version | Install |
|---|---|---|
| Go | 1.26+ | <https://go.dev/dl>, or `brew install go` |
| git | any | You probably have it |

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

Then it renders a test composition, and builds function-template-go once so
Go's caches are warm. After that the labs work offline.

You're done when it prints **You're ready for the labs.** If it asks you to
add `~/.local/bin` to your `PATH`, do that and open a new terminal.

It downloads about 250 MB and uses about 3 GB of disk, mostly Go's build
cache. To install somewhere else, run `BIN_DIR=/some/dir ./scripts/setup.sh`.

## Optional

| Tool | Needed for |
|---|---|
| A GitHub account | Lab 5: opening a PR |
| `gh`, logged in | Lab 5, from the terminal. The browser works too. |
| Docker, kind, kubectl, helm | Lab 6 (take-home). Also building the package image yourself in Lab 5, though CI builds it for you either way. |

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
