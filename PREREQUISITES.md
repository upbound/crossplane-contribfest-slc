# Prerequisites

The fastest way in is a **GitHub Codespace**. Use the button in the
[README](README.md). Everything below is already installed there, and images
are pulled over GitHub's network, not the conference Wi-Fi.

If you'd rather work on your laptop, set it up **before the session**:

| Tool | Version | Needed for | Install |
|---|---|---|---|
| Go | 1.26+ | all labs | <https://go.dev/dl> |
| Docker | any recent | all labs: `crossplane composition render` runs the render engine and functions in containers | Docker Desktop, OrbStack, Colima, … |
| Crossplane CLI | v2.5+ | all labs | `curl -sfL https://cli.crossplane.io/install.sh \| sh`, then move `crossplane` onto your `PATH` |
| git | any | all labs | |
| golangci-lint | v2.12.0 | Lab 5 | <https://golangci-lint.run/welcome/install/> or `go run github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.12.0` |
| gh | any | Lab 5 (or use the browser) | <https://cli.github.com> |
| kind, kubectl, helm | recent | Lab 6, take-home | <https://kind.sigs.k8s.io>, <https://kubernetes.io/docs/tasks/tools/>, <https://helm.sh> |

Then run the check. It also pre-pulls the images and warms your Go module
cache:

```shell
git clone https://github.com/upbound/crossplane-contribfest-slc
cd crossplane-contribfest-slc
./scripts/check-env.sh
```

> **⚠️ Old CLI?** `crossplane beta trace` and the Crossplane-repo install
> script are from before v2.5. The CLI now lives in
> [crossplane/cli](https://github.com/crossplane/cli). If
> `crossplane composition render --help` fails, reinstall from
> `cli.crossplane.io`.

You need a GitHub account for Lab 5.
