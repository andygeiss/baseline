# Operations: CLI Release

**Last verified: 2026-08-25**

How a [CLI tool](../project-types/cli-tool.md) reaches its users. For a CLI the
release *is* the deployment — and the release is a tag. There is no build server and
no artifact: `go install` builds the tool on the machine that will run it, from the
tag, with the same static-binary flags every gate proves.

## Distribution

**`go install github.com/andygeiss/<tool>@latest`** — the one channel. It works because
the `main` package sits at the module root and version reporting uses
`debug.ReadBuildInfo` (see [patterns/go-cli.md](../patterns/go-cli.md)) — no build
flags required. In the sanctioned multi-binary layout (`cmd/<name>/`), the install
path gains the suffix: `go install github.com/andygeiss/<tool>/cmd/<name>@latest`.

Nothing more until real demand exists: no release binaries, no Homebrew tap, no
apt/rpm repos, no Docker images, no install-script-piped-to-shell. A user without a Go
toolchain is real demand — when one appears, cross-compile for that machine by hand
(`CGO_ENABLED=0 GOOS=… GOARCH=… go build -trimpath .`) and hand the file over the way
that user takes files. Automate it the second time it happens, not the first.

## Versioning

- Semver tags, `vX.Y.Z`, on `main` only, with `make ci` green on the commit being
  tagged.
- Patch = fixes, minor = new flags/subcommands, **major = any breaking change to
  the observable contract**: flag names and defaults, exit codes, `-json` field
  names, or the meaning of stdout output. Scripts depend on all of these; treat
  them like a library API.
- **A major past v1 moves the module path too** — `github.com/andygeiss/<tool>/v2`
  in `go.mod` and in every internal import, before the tag exists. Skip it and Go
  refuses the tag for the main module without saying so: `@latest` keeps resolving
  to the v1 line, and the binary stamps a v1 pseudo-version
  ([patterns/go-cli.md](../patterns/go-cli.md)).
- Human-facing stderr text MAY change in any release.

## Cutting a release

```sh
make ci                        # the gates, against the commit you are about to tag
git tag vX.Y.Z && git push origin main vX.Y.Z
GOMODCACHE=$(mktemp -d) go install github.com/andygeiss/<tool>@vX.Y.Z && <tool> -version
```

The last line is the release check: an empty module cache proves the tag resolves
from the proxy and not from this machine, and the version line proves the stamp.
Tests ran on the tagged commit because `make ci` ran on it — "it was green when I
pushed" and "it is green on the tag" are the same commit here, which was the whole
reason the old release workflow ran them twice.

## Rollback

A bad release is fixed by tagging `vX.Y.Z+1`, never by moving or deleting a
published tag — `go install` proxies (proxy.golang.org) cache tags forever, so a
moved tag ships two different binaries under one version. If a release is
actively harmful, retract it in `go.mod` (`retract vX.Y.Z`) in the next release.
