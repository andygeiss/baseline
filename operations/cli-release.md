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
`go install github.com/andygeiss/<tool>/cmd/<name>@latest`. Past v1 it gains the
major too, `go install github.com/andygeiss/<tool>/v2@latest`: on the bare path,
`@latest` stays on the v1 line.

Nothing more until real demand exists: no release binaries, no Homebrew tap, no apt/rpm
repos, no Docker images, no install-script-piped-to-shell. A user without a Go toolchain
is real demand. Build for that machine by hand, at the tagged commit with a clean tree —
anywhere else the stamp is not the tag. A multi-binary module builds `./cmd/<name>`
in place of `.`; `bin/` is gitignored:

```sh
CGO_ENABLED=0 GOOS=… GOARCH=… go build -trimpath -o bin/ .
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
  in `go.mod`, in every internal import, and in every install line, before the tag
  exists. Skip it and
  `@latest` keeps resolving to the v1 line, `go install <tool>@v2.0.0` refuses the
  mismatch, and a checkout build at the tag stamps a v1 pseudo-version
  ([patterns/go-cli.md](../patterns/go-cli.md)).
- Human-facing stderr text MAY change in any release.

## Cutting a release

`make ci` runs the gates against the commit you are about to tag, and a red run stops
the tag and the push:

```sh
make ci && git tag -a vX.Y.Z -m "what changed, in one line" && git push --atomic origin HEAD:main vX.Y.Z
```

If the push fails, `git ls-remote origin refs/tags/vX.Y.Z` says whether it landed
anyway. If that prints nothing, nothing was published: delete the tag
(`git tag -d vX.Y.Z`), fix the cause, and run the tag line again. If it prints the tag,
the release is out. Only once the tag is on the remote, install it from an empty module
cache. Past v1 the path ends in the module's `/vN`, as in
`github.com/andygeiss/<tool>/v2@v2.0.0`, and the binary is still `<tool>`; a tool with
subcommands answers `<tool> version` in place of `<tool> -version`:

```sh
(d=$(mktemp -d) && trap 'GOMODCACHE=${d:?} go clean -modcache' EXIT INT TERM HUP && GOMODCACHE=$d go install github.com/andygeiss/<tool>@vX.Y.Z && <tool> -version)
```

- **The tag message is the release note.** `git log` between two tags is the
  changelog.
- **`HEAD:main` puts the tag on `main`.** A bare `main` pushes the local branch, so a
  tag made on another branch would go out on a commit `main` does not have.
- **The `go install` is the release check, so it waits for the push.** An empty module
  cache proves the tag resolves over the network, not from this machine. Asked before
  the tag exists, proxy.golang.org can go on answering that the version does not exist
  for up to 30 minutes. The check line exits with the check's status.
- **A private repository needs `GOPRIVATE=github.com/<owner>/*`** and GitHub
  credentials for git: the proxy cannot see it, so the check resolves straight from
  GitHub, still from an empty module cache. `go install` stays the one channel.
- **The version check proves the stamp** only if `<tool>` is the copy `go install`
  just wrote; `command -v <tool>` says which copy `PATH` found.
- **The check line deletes its cache, and only that one, whether the check passes,
  fails, or is interrupted.** Its directories are read-only, so `rm -rf` refuses. The
  trap is set only once `mktemp` has made the directory, and it names the signals
  because zsh runs no EXIT trap in a subshell a signal ends. `d` lives and dies inside
  the parentheses: a shell can already hold a `d` of its own (oh-my-zsh leaves one),
  and `go clean -modcache` deletes whatever directory `GOMODCACHE` names.

## Rollback

Fix a bad release by tagging `vX.Y.Z+1`, never by moving or deleting a published
tag. proxy.golang.org keeps a version it has served after the origin changes, and
sum.golang.org records its hash for good, so a moved tag ships two binaries under one
version or fails verification. If a release is actively harmful, retract it in
`go.mod` (`retract vX.Y.Z`) in the next release.
