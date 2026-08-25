# Stack: Make

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-25

**Two of rule 6's four limits are tier 1 and never waived:** `.env` is gitignored in the
same commit that adds the recipe, and production never uses it. A committed `.env` leaks
a secret permanently.

Every project ships one `Makefile` at the repository root. It is the single command
surface, and since there is no CI server it is the only one: `make` runs every gate,
`make ci` runs them against the commit, `make test`/`make run` serve the inner loop.
Make is chosen because it is boring and already installed on every machine —
including macOS, which bundles GNU Make **3.81** (2006; Apple ships no GPLv3
software). That version is the compatibility floor.

Make here is a **command runner, not a build system**. The Go toolchain owns all
dependency tracking and caching; Make-level file dependencies would only redo that
work incorrectly. Every target is therefore `.PHONY` and always runs.

## The canonical Makefile (copy verbatim)

```make
# Copied from the baseline (stack/makefile.md). Adjust per its rule 5; record
# any other deviation in the README.

# The main package: ./cmd/server for a web application, . for a single-binary
# CLI.
MAIN = ./cmd/server

# Targets are alphabetical, so the default is named rather than first.
.DEFAULT_GOAL = check
.PHONY: build check ci clean fmt run test

# Release-shaped local binary in bin/ (go build creates the directory).
build:
	CGO_ENABLED=0 go build -trimpath -o bin/ $(MAIN)

# Default. Every gate, in this order (operations/ci.md), against the working
# tree. Run before every commit.
check:
	test -z "$$(gofmt -l .)" || (gofmt -l . && exit 1)
	go vet ./...
	go run honnef.co/go/tools/cmd/staticcheck@latest ./...
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...
	go mod tidy -diff
	go test -race -shuffle=on ./...
	CGO_ENABLED=0 go build -trimpath ./...

# The same gates against the commit, not the working tree: what a CI server
# saw. A file never added, or a .env, cannot make it green. Run before every
# push. go version first, because nothing else records which toolchain ran.
# One shell line, so the trap removes the copy however check ends.
ci:
	go version
	d=$$(mktemp -d); trap 'rm -rf "$$d"' EXIT; git archive HEAD | tar -x -C "$$d" && $(MAKE) -C "$$d" check

clean:
	rm -rf bin/

fmt:
	go run golang.org/x/tools/cmd/goimports@latest -w .

# Loads .env when it is there, so a local start is one command. Only run:
# check and test MUST NOT depend on a developer's machine (rule 6). One shell
# line, because each recipe line gets its own shell.
run:
	set -a; if [ -f .env ]; then . ./.env; fi; set +a; go run $(MAIN)

# The inner loop.
test:
	go test -race -shuffle=on ./...
```

## Rules

1. **`check` is the one list of gates, and `ci` runs that list against the
   commit.** [operations/ci.md](../operations/ci.md) explains the gates; the
   Makefile is where they live. `ci` MUST call `check` rather than list gates of
   its own, so there is nothing to keep in lockstep — a gate added to `check` is
   in `ci` by construction.
2. **Portable subset only.** The file MUST run under GNU Make 3.81: `=`
   assignment, `.PHONY`, `.DEFAULT_GOAL` (new in 3.81, so exactly at the floor),
   plain tab-indented recipes. MUST NOT use post-3.81 features (`.ONESHELL` —
   3.82; `::=` and `$(file …)` — 4.0), BSD-make extensions, or pattern-rule
   metaprogramming. Comments never share a line with a variable assignment —
   Make keeps the whitespace before `#` as part of the value.
3. **Target names are the interface, and they are alphabetical.** `build`,
   `check`, `ci`, `clean`, `fmt`, `run`, `test` mean the same thing in every
   repository, and a target is found by its name rather than its place — which
   is why `.DEFAULT_GOAL` names the default instead of the first line being it.
   A project MAY add a target for a real recurring command (`db-reset`, …), in
   its alphabetical place, never speculatively; a Makefile growing past one
   screen is over-engineering.
4. **No tool bootstrapping, no ldflags, no release logic, no deployment.** Dev
   tools run via `go run …@latest` — the dev-tool exception in
   [stack/go.md](go.md)'s approved list, with the rationale in
   [operations/ci.md](../operations/ci.md); downloads are cached, but the
   `@latest` lookup asks the proxy on every run, so `check` and `fmt` need the
   network. Versions come from `debug.ReadBuildInfo`, never `-ldflags`
   ([patterns/go-cli.md](../patterns/go-cli.md)). A CLI's release is a tag
   ([operations/cli-release.md](../operations/cli-release.md)). **A web
   application's deployment belongs to the operations repository**, which knows
   the server; this Makefile serves the person editing the code, and that person
   is not sitting at the server.
5. **Per-layout adjustments** — exactly these, nothing else:
   - *Single-binary CLI* (`MAIN = .`): a bare `go build .` (the checklist's
     static-build verification, or habit) drops `./<tool>` into the repo
     root — extend `clean` to `rm -rf bin/ <tool>` and add `<tool>` to
     `.gitignore`.
   - *Multi-binary CLI module* (the sanctioned `cmd/<name>/` layout): set
     `MAIN = ./cmd/<name>` for the binary `run` serves, and in `build` replace
     `$(MAIN)` with `./cmd/...` so every binary lands in `bin/`.
   - *Library:* delete `MAIN`, `run`, `build`, and `clean` (nothing creates
     `bin/`) and trim `.PHONY` to `check ci fmt test` — `check`'s
     `go build ./...` already proves everything compiles.
6. **`run` loads `.env` when it is there. Nothing else does.** A binary that
   needs a token or a database URL otherwise needs two commands to start, and
   the second one is the one people forget. The recipe above is the whole
   mechanism — `set -a` exports what the file sets, `if [ -f .env ]` makes the
   file optional. Four limits keep it honest, and all four are MUST:
   - **`run` only.** A `check` or `test` that read `.env` would pass because a
     developer's machine happened to hold a value and fail in `make ci`, which
     has no such file. The gates run against the committed repository, nothing
     else — and `ci` runs them against nothing else by construction.
   - **The file is optional.** A fresh clone must still start, and fail on the
     binary's own missing-configuration message
     ([patterns/go-config.md](../patterns/go-config.md) rule 1) rather than on
     a shell error about a missing file.
   - **`.env` is in `.gitignore`, in the same commit that adds this recipe.**
     A committed `.env` holding a secret is the anti-pattern go-config.md bans;
     being uncommitted is exactly what makes the file allowed to hold one.
   - **Production never uses it.** Deployments pass secrets as files
     (go-config.md, *Secrets*). `.env` is a convenience for a developer's own
     machine and MUST NOT be part of how anything deploys.

## Why each target

- **`build`** — release-shaped (`CGO_ENABLED=0`, `-trimpath`), so "works
  locally" describes the artifact that ships, not a CGO-tainted cousin.
  `bin/` belongs in `.gitignore`.
- **`check` as the default** — typing `make` answers the only question that
  matters before a commit: are the gates green? It duplicates the `test` line
  instead of depending on the target so the gates run in one fixed order; two
  identical lines beat a clever prerequisite graph.
- **`ci`** — the question before a push: are they green *on the commit*? `git
  archive HEAD` writes the committed tree and nothing else into an empty
  directory, so a file never added, a gitignored `.env`, or an edit not yet
  committed cannot turn it green. It is what a CI server did, minus the server;
  `go version` on the first line is the one fact the server used to record for
  you. Commit, `make ci`, push.
- **`clean`** — removes local build outputs only (`bin/`, plus the root binary
  in a `MAIN = .` layout, rule 5). MUST NOT touch Go's build or module caches;
  they are correct and shared.
- **`fmt`** — the one mutating fixer (`goimports` = gofmt + import management,
  per [stack/go.md](go.md)). The read-only gofmt gate in `check` stays the
  authority on "is it formatted".
- **`run`** — `go run`, not build-then-execute; the build cache makes it fast
  and there is no stale binary to accidentally re-run. It is also the one
  target that reads `.env` (rule 6), so starting the app locally stays a
  single command.
- **`test`** — always `-race -shuffle=on`, exactly as `check` runs it. If that is
  too slow for the inner loop, fix the suite, don't fork the flags.

## What NOT to add

The classic Makefile over-engineering, all banned: self-documenting `help`
targets (awk over `##` comments), colored output, `install` and `deploy`
targets, Docker targets, GOOS/GOARCH matrix loops (`go install` builds on the
user's machine, so nobody cross-compiles), includes, and conditionals on the
host OS.

`deploy` is the one worth naming twice, because it is the tempting one. A deploy
target puts one server's name, one server's paths, and one server's SSH account
into every repository that ships there — and then into every repository that
copies this Makefile. The operations repository holds them once instead.

`.env` loading sits half on this list: rule 6 allows it in `run` and nowhere
else. Reading it in `check` or `test` is the banned version, because it makes a
gate depend on a file `make ci` does not have.
