# Stack: Make

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-25

**Two of rule 6's four limits are tier 1 and never waived:** `.env` is gitignored in the
same commit that adds the recipe, and production never uses it. A committed `.env` leaks
a secret permanently.

Every project ships one `Makefile` at the repository root, and it is the only command
surface: `make` runs every gate, `make ci` runs them against the commit, `make test`
and `make run` serve the inner loop.
Make is boring and already installed on every machine. macOS's Command Line Tools
ship GNU Make **3.81**; that version is the compatibility floor.

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

# The same gates against the commit: a file never added, or a .env, cannot
# make it green. Run before every push. go version runs first, inside the
# copy, so the run records which toolchain ran. The archive goes through a
# file so git's exit status stops the run; one shell line so the trap cleans
# up however check ends.
ci:
	t=$$(mktemp); d=$$(mktemp -d); trap 'rm -rf "$$t" "$$d"' EXIT; git archive -o "$$t" HEAD && tar -xf "$$t" -C "$$d" && go -C "$$d" version && $(MAKE) -C "$$d" check

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
   commit.** `ci` MUST call `check` rather than list gates of its own: a gate
   added to `check` is in `ci` by construction. No `export-ignore` in
   `.gitattributes`: `git archive` honours it and the go command does not, so
   `make ci` would test a tree `go install` never builds.
2. **Portable subset only.** The file MUST run under GNU Make 3.81: `=`
   assignment, `.PHONY`, `.DEFAULT_GOAL` (new in 3.81, so exactly at the floor),
   plain tab-indented recipes. MUST NOT use post-3.81 features (`.ONESHELL` —
   3.82; `::=` and `$(file …)` — 4.0), BSD-make extensions, or pattern-rule
   metaprogramming. Comments never share a line with a variable assignment —
   Make keeps the whitespace before `#` as part of the value.
3. **Target names are the interface, and they are alphabetical.** `build`,
   `check`, `ci`, `clean`, `fmt`, `run`, `test` mean the same thing in every
   repository. You find a target by its name, not its place, which is why
   `.DEFAULT_GOAL` names the default instead of the first line being it.
   A project MAY add a target for a real recurring command (`db-reset`, …), in
   its alphabetical place, never speculatively; a Makefile growing past one
   screen is over-engineering.
4. **No tool bootstrapping, no ldflags, no release logic, no deployment.** Dev
   tools run via `go run …@latest` — the dev-tool exception in
   [stack/go.md](go.md)'s approved list, with the rationale in
   [operations/ci.md](../operations/ci.md). Go caches the downloads, but the
   `@latest` lookup asks the proxy on every run, so `check` and `fmt` need the
   network. Versions come from `debug.ReadBuildInfo`, never `-ldflags`
   ([patterns/go-cli.md](../patterns/go-cli.md)). A CLI's release is a tag
   ([operations/cli-release.md](../operations/cli-release.md)). **A web
   application's deployment belongs to the operations repository**, which knows
   the server.
5. **Per-layout adjustments** — exactly these, nothing else:
   - *Single-binary CLI* (`MAIN = .`): `go build .` drops `./<tool>` into the
     repository root. Extend `clean` to `rm -rf bin/ <tool>` and add `<tool>`
     to `.gitignore`.
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
   - **`run` only.** A `check` or `test` that read `.env` would pass on the
     developer's machine and fail in `make ci`. `ci` runs the gates against the
     committed repository and nothing else, and `.env` is not committed.
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
- **`ci`** — the question before a push: are they green *on the commit*? Read
  the `go version` line.
- **`clean`** — removes local build outputs only (`bin/`, plus the root binary
  in a `MAIN = .` layout, rule 5). MUST NOT touch Go's build or module caches;
  they are correct and shared.
- **`fmt`** — the one mutating fixer (`goimports` = gofmt + import management,
  per [stack/go.md](go.md)). The read-only gofmt gate in `check` stays the
  authority on "is it formatted".
- **`run`** — `go run`, not build-then-execute; the build cache makes it fast
  and there is no stale binary to accidentally re-run.
- **`test`** — always `-race -shuffle=on`, exactly as `check` runs it. If that is
  too slow for the inner loop, fix the suite, don't fork the flags.

## What NOT to add

The classic Makefile over-engineering, all banned: self-documenting `help`
targets (awk over `##` comments), colored output, `install` and `deploy`
targets, Docker targets, GOOS/GOARCH matrix loops (the rare by-hand
cross-compile is one shell line in
[operations/cli-release.md](../operations/cli-release.md), never a target),
includes, and conditionals on the host OS.
