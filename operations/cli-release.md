# Operations: CLI Release

**Last verified: 2026-08-25**

How a [CLI tool](../project-types/cli-tool.md) reaches its users. For a CLI the
release *is* the deployment — and the release is a tag. There is no build server and
no artifact: `go install` builds the tool on the machine that will run it, from the
tag. `make check` proves it builds with cgo off; `go install` uses the user's own cgo
setting, and the result only has to run on that user's machine.

## `go install` is the one channel

**`go install github.com/andygeiss/<tool>@latest`** works because the `main` package
sits at the module root and version reporting uses `debug.ReadBuildInfo` (see
[patterns/go-cli.md](../patterns/go-cli.md)) — no build flags required. In the
sanctioned multi-binary layout (`cmd/<name>/`), the install path gains the suffix:
`go install github.com/andygeiss/<tool>/cmd/<name>@latest`.

Nothing more until real demand exists: no release binaries, no Homebrew tap, no apt/rpm
repos, no Docker images, no install-script-piped-to-shell. A user without a Go toolchain
is real demand. Build for that machine by hand, at the tagged commit with a clean tree —
anywhere else the stamp is not the tag:

```sh
CGO_ENABLED=0 GOOS=… GOARCH=… go build -trimpath -o bin/ .   # or ./cmd/<name>; bin/ is gitignored
```

Hand the file over the way that user takes files, with its `sha256`.

## Versioning

- Semver tags, `vX.Y.Z`, on `main` only, with `make ci` green on the commit being
  tagged.
- Patch = fixes, minor = new flags/subcommands, **major = any breaking change to
  the observable contract**: flag names and defaults, exit codes, `-json` field
  names, or the meaning of stdout output. Scripts depend on all of these; treat
  them like a library API.
- **A major past v1 moves the module path too** — `github.com/andygeiss/<tool>/v2`
  in `go.mod` and in every internal import, before the tag exists. Skip it and
  `@latest` keeps resolving to the v1 line, `go install <tool>@v2.0.0` refuses the
  mismatch, and a checkout build at the tag stamps a v1 pseudo-version
  ([patterns/go-cli.md](../patterns/go-cli.md)).
- Human-facing stderr text MAY change in any release.

## Cutting a release

```sh
make ci                        # the gates, against the commit you are about to tag
git tag -a vX.Y.Z -m "what changed, in one line" && git push --atomic origin main vX.Y.Z
d=$(mktemp -d); GOMODCACHE=$d go install github.com/andygeiss/<tool>@vX.Y.Z && <tool> -version   # or: <tool> version
GOMODCACHE=$d go clean -modcache
```

- **The tag message is the release note.** `git log` between two tags is the
  changelog.
- **The `go install` line is the release check.** An empty module cache proves the
  tag resolves over the network, not from this machine.
- **The version line proves the stamp** only if `<tool>` is the copy `go install`
  just wrote; `command -v <tool>` says which copy `PATH` found.
- **The last line deletes the cache.** Its directories are read-only, so `rm -rf`
  refuses.

## Rollback

Fix a bad release by tagging `vX.Y.Z+1`, never by moving or deleting a published
tag. proxy.golang.org keeps a version it has served after the origin changes, and
sum.golang.org records its hash for good, so a moved tag ships two binaries under one
version or fails verification. If a release is actively harmful, retract it in
`go.mod` (`retract vX.Y.Z`) in the next release.
