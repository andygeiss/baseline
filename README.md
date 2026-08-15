# Engineering Baseline

**Single source of truth for how I build software.** This repository closes the gap
between an LLM's training data and the current state of the art. AI agents working on
any of my projects MUST consult this baseline before making stack, version, or pattern
decisions — do not rely on training data for anything covered here.

**Scope: how software is built here, not how a server is run.** Deployment,
servers, containers, and their versions live in the operations repository
(`baseline-ops`). The seam is one question — *does this fact change the code, or
only the server?* — and this repository owns the first answer. What it publishes
to the second is one document: the deployment contract in
[`operations/web-application.md`](operations/web-application.md).

**The bar: production grade, simplicity first, performant and secure out of the box.**
Boring technology, one static Go binary, hypermedia over JavaScript, security as
layered defaults rather than a checklist. Every rule exists to make the *default*
path the correct one — an agent that follows the documents verbatim ships a correct,
hardened application without inventing anything.

- **Last verified:** 2026-08-15
- **Format:** Markdown only, plus the MIT `LICENSE`. No code, no CI, no build
  steps. Documents are the product.
  The one piece of tooling is the root `Makefile`, which installs the baseline into
  Claude Code (see below) — it builds nothing.

## How to use this repository (AI agents)

Follow this protocol top-down. Never skip to a leaf document without reading its parent.

1. **Identify the project type** you are building (e.g. "web application").
2. **Open the matching document in [`project-types/`](project-types/).**
   It defines the mandated stack and links to everything that applies.
3. **Read the linked [`stack/`](stack/) documents** for language/tool conventions
   and the linked [`patterns/`](patterns/) documents for concrete implementation patterns.
4. **Check [`VERSIONS.md`](VERSIONS.md)** and adopt exactly those versions, the way its
   version policy prescribes (e.g. `go 1.26` in `go.mod`, never a pinned toolchain patch). If a version in
   your training data is newer than what is listed here, the baseline wins — flag the
   discrepancy to the user instead of silently upgrading.
5. **Before declaring work done,** walk the matching document in [`checklists/`](checklists/).

Rules in these documents use RFC-2119 style keywords: **MUST**, **MUST NOT**, **SHOULD**, **MAY**.

## Install into Claude Code

```sh
make install    # symlinks this repo to ~/.claude/skills/engineering-baseline
make uninstall  # removes the symlink
```

Claude Code then loads the baseline as a skill ([SKILL.md](SKILL.md)) whenever a
stack, version, or pattern decision comes up. The symlink keeps the repository
the single copy — `git pull` is the update mechanism. This Makefile is repo
tooling, not the project Makefile that [stack/makefile.md](stack/makefile.md)
prescribes. That document's rules (including the `install`-target ban) govern
projects built *from* the baseline, not the baseline itself.

## Repository structure

```
baseline/
├── checklists/                     ← definition of done per project type
│   ├── cli-tool.md
│   ├── library.md
│   └── web-application.md
├── LICENSE                         ← MIT
├── Makefile                        ← make install / make uninstall (Claude Code)
├── operations/                     ← CI, releases, and the deployment contract
│   ├── ci.md
│   ├── cli-release.md
│   └── web-application.md
├── patterns/                       ← concrete, copyable implementation patterns
│   ├── css-icons.md
│   ├── css-layout.md
│   ├── css-motion.md
│   ├── css-surfaces.md
│   ├── css-tokens.md
│   ├── css-typography.md
│   ├── design-system.md
│   ├── go-auth-sessions.md
│   ├── go-cli.md
│   ├── go-config.md
│   ├── go-errors-logging.md
│   ├── go-forms-validation.md
│   ├── go-http-client.md
│   ├── go-http-server.md
│   ├── go-library.md
│   ├── go-performance.md
│   ├── go-project-layout.md
│   ├── go-sqlite.md
│   ├── go-testing.md
│   ├── htmx-server-rendering.md
│   ├── pwa.md
│   └── security-headers.md
├── project-types/                  ← entry point per kind of project
│   ├── cli-tool.md
│   ├── library.md
│   └── web-application.md
├── README.md                       ← you are here: navigation protocol
├── SKILL.md                        ← makes the repo a Claude Code skill
├── stack/                          ← per-technology conventions
│   ├── css.md
│   ├── go.md
│   ├── html.md
│   ├── htmx.md
│   └── makefile.md
├── STYLE.md                        ← how everything for humans is written
└── VERSIONS.md                     ← pinned versions, dated, with sources
```

## Core engineering values

These apply to every project regardless of type:

1. **Boring technology.** Standard library first. Every dependency must justify itself.
2. **No JavaScript.** Interactivity comes from htmx and modern CSS. If a feature seems
   to require custom JS, redesign the feature (see [stack/html.md](stack/html.md)).
3. **Server is the source of truth.** State lives on the server; the client renders hypermedia.
4. **Simplicity over cleverness.** Code is read far more often than written.
5. **Current, not bleeding edge.** Latest *stable* versions, never betas/RCs in production.
6. **Write for humans.** Every doc, comment, and prompt passes the 10-year-old
   test in [STYLE.md](STYLE.md): point first, short sentences, plain words.

## Quality bar & verification

- **Adversarial review covers every tagged release:** independent reviewers hunt
  cross-document contradictions, trace every canonical snippet's mechanics end to end,
  and verify factual claims against upstream sources (Go, htmx, scs, SQLite) —
  repeated until **two consecutive passes find zero defects**.
  Last run: 2026-08-15, over the **operations split** — the change that moved
  servers, containers, and their versions out to `baseline-ops` and left this
  repository the deployment contract. Sixteen defects fixed across twelve
  documents. The two that mattered: the split dropped the fact that
  `X-Forwarded-For` arrives holding **one address, not a chain**, which is a
  code-affecting fact with a consumer (the per-IP rate limiter) and no fallback
  to `RemoteAddr` for the no-proxy case, so every visitor keyed on `""`; and
  `VACUUM INTO` still named a systemd `StateDirectory` path, which a relative
  path would not have reached anyway — `VACUUM INTO` resolves against the
  process's working directory, not the database's. The rest were stale
  references to the removed products (`journal`, "owns the topology"), a
  `deployment uses a container image` claim in the file that had just said this
  repository describes no deployment, `HTTPS everywhere` left standing over a
  binary that only speaks plain HTTP, and a missing `HOST` obligation that
  leaves a containerised app silently unreachable on loopback. The replacement
  `VACUUM INTO ?` snippet was **verified by running it** — bound parameter,
  `modernc.org/sqlite`, Go 1.26.6, `gofmt` and `go vet` clean. Every relative
  link, every cross-document `rule N` reference, and every file tree's
  alphabetical order were re-checked mechanically. Two further passes over the
  corrected corpus found nothing. **Caveat:** the reference repository was not
  re-synced, so the independent empirical round is again missing.
  Previous run: 2026-08-15, a **full-corpus sweep**. Seven defects fixed across
  eight documents: a two-pool SQLite snippet that does not compile and drops
  both mandatory error checks; a bottom-navigation rule that told readers to
  delete a grid row the fixed bar never vacated (`position: fixed` sits on
  `footer nav`, so `<footer>` stays a grid item); htmx's history cache named as
  `sessionStorage` when it is `localStorage`, which outlives the tab and the
  browser rather than the session; a `primary` palette described as required by
  the `design.md` spec, which in fact only warns and lets tools invent one; a
  `debug.ReadBuildInfo` one-liner that discarded the `ok` result it needs to
  check; two list recipes whose `list-style: none` silently strips list
  semantics in Safari; and a field error tied to its control for the eye only.
  **The mechanical layer was re-verified by running it, not by reading it.**
  Every canonical Go snippet was compiled and put through `gofmt`, `go vet`,
  `staticcheck`, and `govulncheck`; the canonical `Makefile` ran green end to
  end under macOS's GNU Make 3.81; every pinned version was checked against
  upstream; and every measured color claim was recomputed from the oklch values
  — the contrast floors and both manifest hex values came out exactly as
  written. Two further passes over the corrected documents found nothing.
  **One caveat, recorded rather than smoothed over:** the reference repository
  was not re-synced in this run, so the independent empirical round is missing.
  These fixes are verified against the toolchain and upstream sources, not
  against a building application.
  Earlier runs: 2026-08-14, a re-review of the v1.14.0 additions
  (security-headers, go-http-client, go-config), 4 defects; 2026-08-13 over
  css-typography and css-icons (7 rounds, 29 defects, converged).
- **The reference implementation is the executable check.**
  [baseline-reference](https://github.com/andygeiss/baseline-reference) implements
  these rules end to end and MUST be synced to every tagged release — when a rule is
  ambiguous, the reference resolves it.

## Maintenance protocol (humans)

- Every document carries a `Last verified:` date. Re-verify at least **every 3 months**,
  and always after a major release of Go (Feb/Aug) or htmx.
- When updating a version: update `VERSIONS.md` first, then any stack document that
  references behavior of that version, then bump the `Last verified:` dates.
- New recurring decision in a project? Extract it into a pattern document here —
  the whole point is to never solve the same problem twice.
