# Operations: CLI Release

**Last verified: 2026-08-14**

How a [CLI tool](../project-types/cli-tool.md) reaches its users. For a CLI, the
release *is* the deployment — so unlike web applications
([ci.md](ci.md) keeps those manual-and-trivial), a tag-triggered release workflow
is sanctioned here.

## Distribution channels

1. **`go install github.com/andygeiss/<tool>@latest`** — primary channel for
   anyone with a Go toolchain. Works because the `main` package sits at the module
   root and version reporting uses `debug.ReadBuildInfo`
   (see [patterns/go-cli.md](../patterns/go-cli.md)) — no build flags required.
   In the sanctioned multi-binary layout (`cmd/<name>/`), the install path gains
   the suffix — `go install github.com/andygeiss/<tool>/cmd/<name>@latest` — and
   the cross-compile loop below builds `./cmd/<name>` per binary instead of `.`.
2. **GitHub release binaries** — for everyone else. Cross-compiled, static,
   checksummed, built by the workflow below.

Nothing more until real demand exists: no Homebrew tap, no apt/rpm repos, no
Docker images, no install-script-piped-to-shell.

## Versioning

- Semver tags, `vX.Y.Z`, on `main` only, with green CI.
- Patch = fixes, minor = new flags/subcommands, **major = any breaking change to
  the observable contract**: flag names and defaults, exit codes, `-json` field
  names, or the meaning of stdout output. Scripts depend on all of these; treat
  them like a library API.
- Human-facing stderr text MAY change in any release.

## Release workflow

`.github/workflows/release.yml` — runs only on tags; the standard
[ci.yml](ci.md) still gates every push to `main` and every PR:

```yaml
name: release
on:
  push:
    tags: ["v*"]

permissions:
  contents: write   # create the release and upload assets

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-go@v7
        with:
          go-version-file: go.mod
          check-latest: true

      - name: Test
        run: go test -race -shuffle=on ./...

      - name: Cross-compile
        run: |
          mkdir dist
          for os in linux darwin windows; do
            for arch in amd64 arm64; do
              ext=""; [ "$os" = "windows" ] && ext=".exe"
              CGO_ENABLED=0 GOOS=$os GOARCH=$arch \
                go build -trimpath -o "dist/${TOOL}_${os}_${arch}${ext}" .
            done
          done
        env:
          TOOL: mytool   # ← the binary name

      - name: Checksums
        run: cd dist && sha256sum * > SHA256SUMS

      - name: Publish
        run: gh release create "$GITHUB_REF_NAME" dist/* --title "$GITHUB_REF_NAME" --generate-notes
        env:
          GH_TOKEN: ${{ github.token }}
```

## Why it looks like this

- **No goreleaser.** The 12-line loop above is the entire feature set this
  baseline needs from it; a release tool would be one more dependency with its own
  config file, versions, and CVEs.
- **Six targets** (linux/darwin/windows × amd64/arm64) cover every machine that
  matters; add a target when a user actually asks.
- **`-trimpath` + `CGO_ENABLED=0`** — same static-binary invariant CI proves on
  every push to `main`, plus paths stripped so builds don't leak the runner's filesystem
  and stay reproducible across machines.
- **Tests run again on the tag** — the tag commit is what ships; "it was green
  when I pushed" is not the same commit guarantee.
- **`SHA256SUMS`** — lets any downloader verify integrity with stock tooling:
  `sha256sum -c SHA256SUMS`.

## Rollback

A bad release is fixed by tagging `vX.Y.Z+1`, never by moving or deleting a
published tag — `go install` proxies (proxy.golang.org) cache tags forever, so a
moved tag ships two different binaries under one version. If a release is
actively harmful, retract it in `go.mod` (`retract vX.Y.Z`) in the next release
and mark the GitHub release as such.
