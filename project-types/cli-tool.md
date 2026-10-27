# Project Type: CLI Tool

**Last verified: 2026-09-05**

Command-line tool: starts, does one job, exits. If the process is meant to stay up
and serve requests, it is not a CLI — build a [web application](web-application.md).

## Mandated stack

| Layer | Technology | Rule |
|---|---|---|
| Language | Go (stdlib) | MUST. Same conventions as everywhere: [stack/go.md](../stack/go.md). |
| Flags | stdlib `flag`, one `FlagSet` per subcommand | MUST. No cobra, viper, urfave/cli, kong. |
| Config | flags > env vars > built-in defaults | MUST. No config files until genuinely needed — see [patterns/go-config.md](../patterns/go-config.md). |
| Output | stdout = data, stderr = everything else | MUST. See [patterns/go-cli.md](../patterns/go-cli.md). |
| Machine output | `encoding/json/v2` behind a `-json` flag | SHOULD, when other programs consume the output. |
| Outbound HTTP | stdlib `http.Client`, built in `run()` | MUST when the tool calls an API. Never `http.DefaultClient` — see [patterns/go-http-client.md](../patterns/go-http-client.md). |
| Persistence | none; SQLite (`modernc.org/sqlite`) if the tool keeps state | SHOULD prefer stateless. |
| Build | static (`CGO_ENABLED=0`), gated by `make check` | MUST. |
| Distribution | `go install`; the release is a tag, no release binaries until a user without a Go toolchain asks | MUST. See [operations/cli-release.md](../operations/cli-release.md). |
| Local commands | Make | MUST. `Makefile` from [stack/makefile.md](../stack/makefile.md), with the rule-5 adjustments for its layout. |
| Specification | `SPEC.md` at the repo root | MUST. Job and Why, one line each; Guardrails pointing at the waivers and the named decisions; Done means: the checklist plus `make ci`. Every task's brief is a delta against it — [README.md](../README.md) *The task brief*. |

Versions: see [VERSIONS.md](../VERSIONS.md).

## Required reading (in order)

These two apply to every CLI, so read them before the first line of code. The order
is dependency order.

1. [stack/go.md](../stack/go.md) — language conventions and toolchain
2. [patterns/go-cli.md](../patterns/go-cli.md) — the `run()` pattern, flags, streams, exit codes, version

**A document is required only when it changes a decision you make before the first
line of code.** Anything you can read at the moment you write the thing is a trigger
section in the checklist — that is the difference, and it is what keeps this list short.

## Open when you reach the thing it covers

The triggers are in [checklists/cli-tool.md](../checklists/cli-tool.md), one section
each: the moment it fires, the document, and the boxes it will be checked against. Read
it now to learn which moments fire which document, then open each document when you reach
the thing it covers.

Working on a tool that already follows this document? That file and the tool's
`SPEC.md` are the only ones you need — everything above is a decision already made.

## Architecture defaults

- **Layout:** for the common case — a module that ships exactly one binary — the
  `main` package lives at the **module root** (wiring only, same size budget as
  [patterns/go-project-layout.md](../patterns/go-project-layout.md)), all logic in
  `internal/`. This makes the install path clean:
  `go install github.com/andygeiss/<tool>@latest`. Use `cmd/<name>/` only when one
  module genuinely ships several binaries.
- **The `run()` pattern.** `main` parses nothing and decides nothing: it builds a
  signal-aware context, calls `run(ctx, args, stdout, stderr)`, maps the returned
  error to an exit code. `os.Exit` appears in `main` only. Details and canonical
  code in [patterns/go-cli.md](../patterns/go-cli.md).
- **A CLI terminates.** Ctrl-C/SIGTERM cancels the context and the tool exits
  cleanly, finishing or rolling back the current unit of work. No daemon mode, no
  `--watch` loops by default — a process that should run forever is a different
  project type.
- **No interactivity.** Everything arrives via flags, arguments, environment, or
  stdin. No prompts, no TUI. A tool that needs a conversation with the user
  probably wants to be a web application.
- **Subcommands are a smell until they aren't.** Single-purpose tools take flags
  only. Add manual dispatch (stdlib, ~10 lines) when the tool genuinely does
  several things; at more than ~5 subcommands, question whether it is several tools.
- **Check the name with `command -v` before you commit to it.** A plain English
  word is a name somebody already took: the reference client below was called
  `chat` for a day, and `/usr/sbin/chat` is a PPP utility on every macOS box — so
  the tool a person installed was not the tool that ran, with nothing to say so.
  Prefix it (`gochat`) and the collision is gone. The env vars follow the name
  ([patterns/go-config.md](../patterns/go-config.md) rule 6), so renaming later
  moves those too — which is why this is a decision to make first.

## Definition of done

Re-read the brief, then walk the boxes of that same file before calling any milestone
complete.

## Reference implementation

The `gochat` client in
[github.com/andygeiss/baseline-reference](https://github.com/andygeiss/baseline-reference)
implements this document end to end (deviations recorded in its README). When a
rule here is ambiguous, read how the reference does it.

It is the sanctioned multi-binary case: the module ships a server and a client,
so `main` sits in `cmd/gochat/` rather than at the module root, and the install
path gains the suffix.

**The one part it does not exercise is semver** — that repository's tags mirror
baseline versions rather than the tool's own contract, so its version numbers say
nothing about `gochat`. The channel in
[operations/cli-release.md](../operations/cli-release.md) works:
`go install github.com/andygeiss/baseline-reference/vN/cmd/gochat@<tag>` (`N` the
tag's major) resolves and `gochat version` prints the tag. The author checks that by
hand at each tag, because `verify.sh` cannot gate a tag that does not exist yet.
