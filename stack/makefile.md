# Stack: Make

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-15

**Two of rule 6's four limits are tier 1 and never waived:** `.env` is gitignored in the
same commit that adds the recipe, and production never uses it. A committed `.env` leaks
a secret permanently.

Every project ships one `Makefile` at the repository root. It is the single local
command surface: `make` runs every gate CI runs, `make test`/`make run` serve the
inner loop. Make is chosen because it is boring and already installed on every
machine — including macOS, which bundles GNU Make **3.81** (2006; Apple ships no
GPLv3 software). That version is the compatibility floor.

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

.PHONY: check test run fmt build clean

# Default. Every gate CI runs, identically and in the same order
# (operations/ci.md). Green here means green CI — run before every push.
check:
	test -z "$$(gofmt -l .)" || (gofmt -l . && exit 1)
	go vet ./...
	go run honnef.co/go/tools/cmd/staticcheck@latest ./...
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...
	go mod tidy -diff
	go test -race -shuffle=on ./...
	CGO_ENABLED=0 go build -trimpath ./...

# The inner loop.
test:
	go test -race -shuffle=on ./...

# Loads .env when it is there, so a local start is one command. Only run:
# check and test MUST NOT depend on a developer's machine (rule 6). One shell
# line, because each recipe line gets its own shell.
run:
	set -a; if [ -f .env ]; then . ./.env; fi; set +a; go run $(MAIN)

fmt:
	go run golang.org/x/tools/cmd/goimports@latest -w .

# Release-shaped local binary in bin/ (go build creates the directory).
build:
	CGO_ENABLED=0 go build -trimpath -o bin/ $(MAIN)

clean:
	rm -rf bin/
```

## Rules

1. **`check` mirrors [operations/ci.md](../operations/ci.md) gate-for-gate** —
   same commands, same flags, same order. Any change to one MUST land in the
   other in the same commit. CI deliberately keeps its explicit named steps
   rather than calling `make check`: per-gate red/green in the Actions UI is
   worth the duplication, and the lockstep rule is what keeps it honest.
2. **Portable subset only.** The file MUST run under GNU Make 3.81: `=`
   assignment, `.PHONY`, plain tab-indented recipes. MUST NOT use post-3.81
   features (`.ONESHELL` — 3.82; `::=` and `$(file …)` — 4.0), BSD-make
   extensions, or pattern-rule metaprogramming. Comments never share a line with a variable assignment —
   Make keeps the whitespace before `#` as part of the value.
3. **Target names are the interface.** `check`, `test`, `run`, `fmt`, `build`,
   `clean` mean the same thing in every repository. A project MAY add a target
   for a real recurring command (`db-reset`, …), never speculatively; a Makefile
   growing past one screen is over-engineering.
4. **No tool bootstrapping, no ldflags, no release logic, no deployment.** Dev
   tools run via `go run …@latest` — the same dev-tool exception CI uses
   ([stack/go.md](go.md) approved list, rationale in
   [operations/ci.md](../operations/ci.md)); downloads are cached, but the
   `@latest` lookup asks the proxy on every run, so `check` and `fmt` need the
   network. Versions come from `debug.ReadBuildInfo`, never `-ldflags`
   ([patterns/go-cli.md](../patterns/go-cli.md)). A CLI's release belongs to
   [operations/cli-release.md](../operations/cli-release.md) and its tagged
   workflow. **A web application's deployment belongs to the operations
   repository**, which knows the server; this Makefile serves the person editing
   the code, and that person is not sitting at the server.
5. **Per-layout adjustments** — exactly these, nothing else:
   - *Single-binary CLI* (`MAIN = .`): a bare `go build .` (the checklist's
     static-build verification, or habit) drops `./<tool>` into the repo
     root — extend `clean` to `rm -rf bin/ <tool>` and add `<tool>` to
     `.gitignore`.
   - *Multi-binary CLI module* (the sanctioned `cmd/<name>/` layout): set
     `MAIN = ./cmd/<name>` for the binary `run` serves, and in `build` replace
     `$(MAIN)` with `./cmd/...` so every binary lands in `bin/`.
   - *Library:* delete `MAIN`, `run`, `build`, and `clean` (nothing creates
     `bin/`) and trim `.PHONY` to `check test fmt` — `check`'s
     `go build ./...` already proves everything compiles.
6. **`run` loads `.env` when it is there. Nothing else does.** A binary that
   needs a token or a database URL otherwise needs two commands to start, and
   the second one is the one people forget. The recipe above is the whole
   mechanism — `set -a` exports what the file sets, `if [ -f .env ]` makes the
   file optional. Four limits keep it honest, and all four are MUST:
   - **`run` only.** A `check` or `test` that read `.env` would pass because a
     developer's machine happened to hold a value and fail in CI, which has no
     such file. The gates run against the committed repository, nothing else.
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

- **`check` as the default** — typing `make` answers the only question that
  matters before a push: would CI be green? It duplicates the `test` line
  instead of depending on the target so the gates run in CI's exact order; two
  identical lines beat a clever prerequisite graph.
- **`test`** — always `-race -shuffle=on`, exactly as CI runs it. If that is
  too slow for the inner loop, fix the suite, don't fork the flags.
- **`run`** — `go run`, not build-then-execute; the build cache makes it fast
  and there is no stale binary to accidentally re-run. It is also the one
  target that reads `.env` (rule 6), so starting the app locally stays a
  single command.
- **`fmt`** — the one mutating fixer (`goimports` = gofmt + import management,
  per [stack/go.md](go.md)). The read-only gofmt gate in `check` stays the
  authority on "is it formatted".
- **`build`** — release-shaped (`CGO_ENABLED=0`, `-trimpath`), so "works
  locally" describes the artifact that ships, not a CGO-tainted cousin.
  `bin/` belongs in `.gitignore`.
- **`clean`** — removes local build outputs only (`bin/`, plus the root binary
  in a `MAIN = .` layout, rule 5). MUST NOT touch Go's build or module caches;
  they are correct and shared.

## What NOT to add

The classic Makefile over-engineering, all banned: self-documenting `help`
targets (awk over `##` comments), colored output, `install` and `deploy`
targets, Docker targets, GOOS/GOARCH matrix loops (the CLI release workflow owns
cross-compilation), includes, and conditionals on the host OS.

`deploy` is the one worth naming twice, because it is the tempting one. A deploy
target puts one server's name, one server's paths, and one server's SSH account
into every repository that ships there — and then into every repository that
copies this Makefile. The operations repository holds them once instead.

`.env` loading sits half on this list: rule 6 allows it in `run` and nowhere
else. Reading it in `check` or `test` is the banned version, because it makes a
gate depend on a file CI does not have.
