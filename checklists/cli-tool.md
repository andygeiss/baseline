# CLI Tool — Triggers and Definition of Done

**Last verified: 2026-09-08**

One topic per section: **the moment it fires, the document that rules it, and what done
looks like.** Read a section before you write the thing it covers; walk its boxes before
you call the work complete. A section with no box is the honest answer where the document
rules something no milestone can verify. Paths are from the repository root.

Every unchecked box is either fixed or waived on the record — the waiver format lives in
`README.md` under *Which rules can be waived*. **Tier 1 is decided by what a rule
protects, not by which section it landed in**, and these are the boxes: partial work
staying safe, a destructive action needing an explicit flag, every box about how a secret
is handled — a secret never arrives as a flag *value*, and `.env` is gitignored — and the
pragmas, the path box, and parameterized SQL under *Storing anything between runs*.
There is no waiver for any of them; there is a fix.

## Every CLI tool

No trigger: these fire for every tool. The `run()` pattern and the command-line contract
are ruled by `patterns/go-cli.md`, which is required reading.

- [ ] `go.mod` says `go 1.27`, matching `VERSIONS.md`, and has no `toolchain` line
- [ ] No `replace` directives on main — every gate passes with one, and `go install` refuses the module
- [ ] No dependencies outside the approved list in `stack/go.md`, or each extra one is justified in the README
- [ ] Flags via stdlib `flag` only — no cobra, viper, or urfave
- [ ] Single static binary builds: `CGO_ENABLED=0 go build .` (or `./cmd/...` in a multi-binary module)
- [ ] `main` package at module root — `cmd/<name>/` only when the module ships several binaries
- [ ] Logic in `internal/`
- [ ] The binary's name is free: `command -v <name>` finds nothing on a stock macOS and Linux box — a collision means the tool that runs is not the tool that was installed (`project-types/cli-tool.md`)
- [ ] `run(ctx, args, stdout, stderr)` pattern, plus a `stdin io.Reader` where the tool reads stdin
- [ ] `os.Exit` in `main` only
- [ ] Every failure surfaces as `tool: <cause>` on stderr, exit 1
- [ ] Ctrl-C/SIGTERM cancels the context
- [ ] In-flight work finishes or rolls back
- [ ] Interrupted runs exit non-zero
- [ ] Partial work is safe: units of work atomic (temp file + rename, transaction) or reruns idempotent
- [ ] README links to this baseline
- [ ] README shows the `go install` line + a 30-second usage example
- [ ] Any waived rule recorded in the format `README.md` *Which rules can be waived* defines
- [ ] `SPEC.md` at the repo root, shaped by `README.md` *The task brief*
- **The brief:**
  - [ ] Every *done means* line is true
  - [ ] Nothing outside *guardrails* changed

### The command-line contract

- [ ] stdout carries data only; diagnostics, progress, and usage go to stderr (`tool > out.txt 2>/dev/null` yields clean data)
- [ ] Exit codes: 0 success, 1 failure, 2 usage error
- [ ] `-h` prints usage and exits 0
- [ ] `-h` documents every flag including its env var default
- [ ] README shows the same
- [ ] `version` subcommand or `-version` flag reports via `debug.ReadBuildInfo` (correct under both `go install @tag` and checkout builds)
- [ ] No prompts, no colors, no ANSI sequences
- [ ] Destructive actions require an explicit `-force`-style flag
- **If `-json` exists:**
  - [ ] One object per line
  - [ ] Field names treated as API

## Naming a concept this tool owns — a domain type, a subcommand, a flag

`patterns/glossary.md` — the optional root `GLOSSARY.md`: one word per concept, the
runners-up under *Avoid*.

- **If the tool keeps a `GLOSSARY.md`:**
  - [ ] The README links it
  - [ ] Every term is the word the code, the subcommands, and the flags use
  - [ ] A `git grep` for each *Avoid* word finds no use of it for that concept, except where its entry says so
  - [ ] No term restates baseline or general-programming vocabulary

## Reading a flag, an environment variable, or a secret

`patterns/go-config.md` — flags over env over defaults, validated before any work starts;
§A CLI holds its secret differently.

- [ ] Config precedence is flags > env > defaults
- [ ] Config parsed and validated before any work starts
- [ ] A bad value exits 2 with one line, never a half-done run
- **Any secret (API token, key)** — §A CLI holds its secret differently:
  - [ ] It is read from a file named by `-token-file`/`$MYTOOL_TOKEN_FILE`
  - [ ] `$MYTOOL_TOKEN` is documented as the leaky fallback
  - [ ] It is **never** taken from a flag value
  - [ ] Handed to a program the tool starts, it never travels on that program's command line — `patterns/go-child-process.md`
- **If the repo has a `.env`** — `stack/makefile.md` rule 6:
  - [ ] It is gitignored
  - [ ] No gate reads it — `check`, `ci`, `test`
  - [ ] Production takes its secrets from credential files instead

## Returning an error, or logging anything

`patterns/go-errors-logging.md` — wrapping, sentinels, and slog.

- [ ] Errors wrapped with `%w`

## Writing a comment, a README, a commit message, an error message, or a prompt

`STYLE.md` — point first, short sentences, plain words: the bar for everything a human
reads.

- [ ] Comments say *why*, not what
- [ ] The README leads with the point
- [ ] Commits are semantic (`type(scope): subject`)
- [ ] Any LLM prompts follow `patterns/llm-prompting.md`

## Writing a test

`patterns/go-testing.md` — what to test, and what never to fake.

- [ ] `go test -race -shuffle=on ./...` passes
- [ ] Core logic in `internal/` covered exhaustively (all rules/edge cases)
- **`run()` is table-tested:**
  - [ ] Happy path per subcommand (or the single command)
  - [ ] Unknown command and top-level `-h` where dispatch exists
  - [ ] Bad flag (→ `errUsage`)
  - [ ] `-json` output parses back line by line with `encoding/json/v2`, where the flag exists

## Depending on someone else's system

`patterns/go-ports-adapters.md` — the port and its fake: build and test the tool before
the API is integrated.

- [ ] The adapter sits in its own package
- [ ] It defines no port of its own
- [ ] It exposes domain methods instead of `*http.Response`
- [ ] It imports `internal/domain` and nothing else of yours — `go list -deps` proves it
- [ ] Every port has a hand-written fake, never a mock
- [ ] Tests assert the outcome, not call counts or call order

## Calling an external API over HTTP

`patterns/go-http-client.md` — timeouts, retries, body limits.

- [ ] Uses an injected client with a timeout, never `http.DefaultClient`
- [ ] Checks `resp.StatusCode`
- [ ] Caps the body it reads

## Starting a program the tool keeps running — a server it fronts, an engine, a database

`patterns/go-child-process.md` — its own process group, one stop sent first, the wait.

- [ ] The child runs in a process group of its own (`Setpgid`)
- [ ] That code sits behind `//go:build unix`
- [ ] SIGTTOU is ignored before the child starts
- [ ] SIGTSTP is ignored before the child starts
- [ ] It is not started with `exec.CommandContext`, whose cancel kills it
- [ ] Its output goes to the tool's stderr
- [ ] Its `Stdout` and `Stderr` are `*os.File`s, never another writer
- [ ] Everything that can fail fast is checked before it starts
- [ ] The readiness wait ends when the child exits, too
- [ ] The stop signal goes to the child's whole process group
- [ ] The tool sends it once, never a second SIGTERM
- [ ] It goes out before the tool's own shutdown
- [ ] The tool waits for the child to exit before it returns, on every path
- [ ] What is left of the group `grace` after the stop signal gets SIGKILL
- [ ] The wait ends as soon as the whole group has gone
- [ ] A child that exits on its own stops the tool
- [ ] That stop's error names the child's exit
- [ ] SIGHUP stops the tool, unless it was started ignored
- [ ] The force-kill hatch ignores SIGHUP before it unregisters the rest
- [ ] Its secret reaches it through a file, or its own environment when it reads nothing else — never its command line
- [ ] Tests run the test binary as the fake child
- [ ] Tests assert the fake child caught SIGTERM before `run` returned
- [ ] The fake child starts a helper, run as a mode of its own
- [ ] The fake logs `complete` only after that helper has gone
- [ ] A test asserts the fake that outlasts SIGTERM is gone when `run` returns
- [ ] A test asserts the deadline counts from the stop, not from the tool's own shutdown
- [ ] A test lets the fake leave its helper behind, and asserts the helper is gone
- [ ] Every wait in a test is bounded
- [ ] `t.Cleanup` kills the fake's group

## Adding an AI capability — a model that answers, summarises, extracts, or classifies

`patterns/go-llm-adapter.md` — the port, the prompt in `domain`, refusals as sentinels. A
tool holds its key differently: `patterns/go-config.md` §A CLI holds its secret
differently.

- [ ] The `claude-api` skill was loaded before the request was written
- [ ] The prompt and conversation shape live in `domain`
- [ ] A refusal is a domain sentinel, checked **before** the response text is read
- [ ] The request is pinned by an `httptest` test rather than the live API

## Writing or tuning a prompt, or reading what a model wrote back

`patterns/llm-prompting.md` — prompt-writing rules, the thinking and effort settings, and
the reasoning that leaks into the visible answer.

- [ ] The thinking/effort setting is explicit
- [ ] The token ceiling covers thinking plus answer
- [ ] The visible answer was read: no reasoning leaked into it

## Storing anything between runs

`patterns/go-sqlite.md` — pragmas, pools, migrations. Prefer staying stateless.

- [ ] Pragmas: WAL, `busy_timeout`, `synchronous(NORMAL)`, `foreign_keys(1)`
- [ ] Path made a file name
- [ ] `sqlite.StrictPragmas(true)`
- [ ] SQL only via parameterized queries
- [ ] Migrations embedded and forward-only

## Setting up the repo's commands or CI

`stack/makefile.md`, then `operations/ci.md` — there is no CI server; the Makefile is the
gate.

- [ ] `Makefile` at the repo root is `stack/makefile.md`'s, differing only as its rules 1, 3 and 5 allow
- [ ] Targets alphabetical
- [ ] `check` named as `.DEFAULT_GOAL`
- [ ] `make check` is green
- [ ] `make ci` is green on the commit being pushed — nothing runs it for you
- [ ] Nothing under `.github/workflows/`
- [ ] No `.github/dependabot.yml`
- [ ] No `export-ignore` in `.gitattributes`
- **If the project has OS-specific files (`//go:build <os>`, or a `_<os>.go` file name):**
  - [ ] `GOOS=<os> go vet ./...` passed for each such OS before the push — for `//go:build unix`, each Unix the tool claims
- **If a file carries a build tag that is not an OS (`//go:build <tag>`):**
  - [ ] `check` has a `go vet -tags <tag> ./...` line for each tag set
- **If a recipe runs a tool whose output is committed or shipped — a generator, a compiler:**
  - [ ] It names an exact version, never `@latest`

## Tagging and publishing a release

`operations/cli-release.md` — the release is a tag, and `go install` is the channel.

- [ ] `make ci` is green on the commit being tagged
- [ ] The tag's message is the release note (an annotated tag)
- [ ] `go install github.com/andygeiss/<tool>@<tag>` (`…/<tool>/vN@<tag>` past v1, `…/cmd/<name>@<tag>` in a multi-binary module) resolves with an empty `GOMODCACHE`
- [ ] `<tool> -version` (or `<tool> version`) prints the tag
- [ ] No release binaries — not until a user without a Go toolchain asks
- [ ] Semver honored: breaking changes to flags, exit codes, `-json` fields, or the meaning of stdout output only in a major release
- [ ] Past v1 the module path carries `/vN`

## Fixing something measurably slow

`patterns/go-performance.md` — and not before. No box: the rule is *don't*, and a rule
nobody can be in the middle of violating has nothing to check at the end.
