# Operations: CI

**Last verified: 2026-08-25**

**There is no CI server.** The [checklists](../checklists/)' mechanical items run on
the developer's machine, from the `Makefile` every project copies
([stack/makefile.md](../stack/makefile.md)), and a commit is pushed when `make ci` is
green against it. A human never checks what a machine can — and the machine is the
one in front of the human.

## The gates

Seven, in this order. `make check` runs them against the working tree; `make ci`
runs the same list against the commit.

```sh
test -z "$(gofmt -l .)" || (gofmt -l . && exit 1)          # Format
go vet ./...                                               # Vet
go run honnef.co/go/tools/cmd/staticcheck@latest ./...     # Staticcheck
go run golang.org/x/vuln/cmd/govulncheck@latest ./...      # Vulncheck
go mod tidy -diff                                          # Tidy
go test -race -shuffle=on ./...                            # Test
CGO_ENABLED=0 go build -trimpath ./...                     # Build (static)
```

## Why each gate exists

- **`govulncheck`** — call-graph-aware CVE scanning, so a vulnerability in a function
  you never call is reported as such and not as red. A red gate means: bump the
  dependency, don't silence the check.
- **`go mod tidy -diff`** — fails instead of mutating; keeps `go.mod`/`go.sum` honest.
- **`-shuffle=on`** — flushes out inter-test ordering dependencies early.
- **`-race`** — mandatory, never dropped for speed. If the suite gets slow, fix the
  suite.
- **`@latest` on staticcheck/govulncheck is a deliberate exception** to version
  pinning: both are analysis gates, not build inputs — a new check can redden the run
  but can never change the shipped binary, and for these tools the newest checks *are*
  the point. If a staticcheck release breaks the gate on an unrelated morning, pin that
  line to the previous version in the fixing commit and remove the pin once the
  findings are addressed.
- **Static build gate** — proves the CGO-free single-binary invariant on every run,
  not at release time.

## Two commands, one list

- **`make check`, before every commit.** The gates against the working tree — what
  you are about to commit, plus whatever else is lying around.
- **`make ci`, before every push.** The same gates against `git archive HEAD`: the
  committed tree, copied to an empty directory, with nothing you forgot to `git add`,
  no `.env`, and no local edit. That is exactly what a CI server used to see, and it
  is the difference between "green on my machine" and "green on the commit". It
  prints `go version` first, because nothing else records which toolchain ran.

`ci` calls `check` rather than listing gates of its own, so there is one list to
edit. The Makefile is that list; this document only explains it.

## Why there is no server

One person writes the code, runs the gates, and pushes. A second machine doing the
same work bought three things and cost four. It bought a run on a clean checkout —
`make ci` does that now. It bought a weekly re-scan of untouched code — the next
paragraph says what replaces it. It bought a per-gate red/green view — a terminal
does that. It cost a hosting vendor, a YAML dialect, a runtime deprecation cycle to
track in [VERSIONS.md](../VERSIONS.md) — two action majors moved in one year — and a
bot opening pull requests nobody but the pusher reads.

**Two things did move from the runner to the person, and both are on the 90-day
cycle.** The Go that runs the gates is the one installed on the machine, so the
patch [VERSIONS.md](../VERSIONS.md) pins is yours to install; `make ci` prints the
version so the run says which one it was. And nothing scans a repository between
commits any more: `govulncheck` runs when somebody runs the gates. A deployed
binary whose code nobody touched is scanned when the pins are next re-verified —
run `make ci` then, on every repository that is live, even when nothing changed.

## Dependency updates

By hand, on the same 90-day cycle, or when [VERSIONS.md](../VERSIONS.md) moves:

```sh
go get -u ./... && go mod tidy && make check
```

One `chore(deps)` commit for all of it. Major-version bumps of the *pinned* stack (Go,
htmx) are never part of it: they go through [VERSIONS.md](../VERSIONS.md) first.
Anything that breaks on a routine update is a candidate for removal.

## Out of scope

**Nothing here deploys, and this repository does not describe deployment at all.**
How a web application reaches a server — and which server — belongs to the
operations repository (`baseline-ops`), because it changes only the server. What
belongs here is the contract the binary must satisfy:
[web-application.md](web-application.md).

The division of labour is the point: the gates answer "is this code good?", and a
person answers "should this go live now?". No CD pipeline, no deploy key anywhere. A
CLI tool's release is a tag, and [cli-release.md](cli-release.md) owns it.

The gates also build no container image, whatever the deployment turns out to run.
Every `make check` would need a container runtime up — to build a file this
repository does not own.
