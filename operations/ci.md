# Operations: CI

**Last verified: 2026-08-25**

**There is no CI server.** One person writes the code, runs the gates, and pushes; a
second machine repeating that work is not worth its upkeep. The mechanical items in the
[checklists](../checklists/) run on the developer's machine, from the `Makefile` every
project copies ([stack/makefile.md](../stack/makefile.md)), and you push a commit when
`make ci` is green against it. A project MUST NOT carry a CI workflow, a release
workflow, or a dependency bot: nothing under `.github/workflows/`, no
`dependabot.yml`.

## Seven gates, one order

Format, Vet, Staticcheck, Vulncheck, Tidy, Test, Build (static). The recipe under
`check` in [stack/makefile.md](../stack/makefile.md) is the list, and the only copy
of it: the Makefile says what runs, and this document says why.

## Why each gate exists

- **`govulncheck`** — call-graph-aware CVE scanning: it reports a vulnerability in a
  function you never call as exactly that, not as red. A red gate means: bump the
  dependency, don't silence the check.
- **`go mod tidy -diff`** — fails instead of mutating; keeps `go.mod`/`go.sum` honest.
- **`-shuffle=on`** — flushes out inter-test ordering dependencies early.
- **`-race`** — mandatory, never dropped for speed. If the suite gets slow, fix the
  suite.
- **`@latest` on staticcheck/govulncheck is a deliberate exception** to version
  pinning: both are analysis gates, not build inputs — a new check can redden the run
  but can never change the shipped binary, and for these tools the newest checks *are*
  the point. If a staticcheck release breaks the gate on an unrelated morning, pin that
  line to the previous version in the fixing commit and remove the pin once you have
  fixed the findings.
- **Static build gate** — proves the CGO-free single-binary invariant on every run,
  not at release time.

## Two commands, one list

- **`make check`, before every commit.** The gates against the working tree — what
  you are about to commit, plus whatever else is lying around.
- **`make ci`, before every push.** The same gates against `git archive HEAD`: the
  committed tree, copied to an empty directory, with nothing you forgot to `git add`,
  no `.env`, and no local edit. That is the difference between "green on my machine"
  and "green on the commit". Read its `go version` line: it is the one record of which
  toolchain ran.

## What `make ci` does not check

`make ci` runs on this machine, so four things are yours:

- **Modules.** `make ci` resolves them from this machine's cache. A module that exists
  only in that cache surfaces at deploy, or in the empty-cache check in
  [cli-release.md](cli-release.md).
- **File-name case.** macOS ignores it; Linux does not. Spell every `//go:embed`
  pattern exactly as `git ls-files` prints the file, or the build fails at deploy or
  in a Linux user's `go install`.
- **Other operating systems.** For every other OS that a `//go:build <os>` line or a
  `_<os>.go` name targets, run `GOOS=<os> go vet ./...` before the push.
- **Your shell.** `GOFLAGS` and whatever else the profile exports or `go env -w`
  wrote reach the gates. Read `go env -changed` before you trust a green run: every
  line it prints is a difference between this machine and the one that builds the
  code next, and each one needs a reason you can say out loud.

Two things nobody does for you:

- **The Go version.** `GOTOOLCHAIN=auto`, the default, runs whatever Go on the machine
  satisfies `go.mod`'s `go 1.26` line — a newer major [VERSIONS.md](../VERSIONS.md)
  has not adopted, or a patch below the floor it names, both included. When the run's
  `go version` line is not the pin, put `GOTOOLCHAIN=go1.26.7` in front of every `go`
  and `make` command — never a `toolchain` line in `go.mod`.
- **The scan.** `govulncheck` runs only when somebody runs the gates. Re-scan untouched
  code on the 90-day cycle: run `make ci` on every live repository, whether or not it
  changed.

## Dependency updates

By hand, under the pin, on the same 90-day cycle or when
[VERSIONS.md](../VERSIONS.md) moves:

```sh
export GOTOOLCHAIN=go1.26.7                       # the pin, for this shell
go get -u ./... && go mod tidy && make check      # one chore(deps) commit
```

Anything that breaks on a routine update is a candidate for removal.

A dependency that asks for a newer Go is a VERSIONS.md decision, not a `go get` side
effect. Under the pin `go get` refuses (`requires go >= 1.27`) and leaves `go.mod`
alone: hold the dependency (`go get -u ./... <dep>@<current>`) or drop it. Under
`auto`, `go get` raises the `go` line instead — one `go: upgraded go 1.26 => 1.27`
line in its output — and any later `go mod tidy` does the same without a word. If
the `go` line rose, put it back by hand, with the pin exported:

```sh
go mod edit -go=1.26 -toolchain=none -require=<dep>@<current> && go mod tidy && make check
```

The hold is `go mod edit -require`, not `go get`: under the pin `go get` cannot open
a `go.mod` that says `go 1.27`, and `go mod edit` never reads the module graph. `go
mod tidy` then refuses while any other dependency still asks for 1.27; give each one
its own `-require`. `-toolchain=none` removes any `toolchain` line, which would pick
the Go for every machine on `auto`.

## Nothing here deploys

**This repository does not describe deployment at all.**
How a web application reaches a server — and which server — belongs to the
operations repository (`baseline-ops`), because it changes only the server. What
belongs here is the contract the binary must satisfy:
[web-application.md](web-application.md).

The division of labour is the point: the gates answer "is this code good?", and a
person answers "should this go live now?". No CD pipeline, no deploy key anywhere. A
CLI tool's release is a tag, and [cli-release.md](cli-release.md) owns it.

The gates also build no container image, whatever the deployment turns out to run.
If they did, every `make check` would need a container runtime up, to build a file
this repository does not own.
