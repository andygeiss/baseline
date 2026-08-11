# Engineering Baseline

**Single source of truth for how I build software.** This repository closes the gap
between an LLM's training data and the current state of the art. AI agents working on
any of my projects MUST consult this baseline before making stack, version, or pattern
decisions — do not rely on training data for anything covered here.

**The bar: production grade, simplicity first, performant and secure out of the box.**
Boring technology, one static Go binary, hypermedia over JavaScript, security as
layered defaults rather than a checklist. Every rule exists to make the *default*
path the correct one — an agent that follows the documents verbatim ships a correct,
hardened application without inventing anything.

- **Owner:** Andy Geiss
- **Last verified:** 2026-08-11
- **Format:** Markdown only. No code, no tooling, no build steps. Documents are the product.

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

## Repository structure

```
baseline/
├── README.md                       ← you are here: navigation protocol
├── VERSIONS.md                     ← pinned versions, dated, with sources
├── STYLE.md                        ← how everything for humans is written
├── project-types/                  ← entry point per kind of project
│   ├── web-application.md
│   ├── cli-tool.md
│   └── library.md
├── stack/                          ← per-technology conventions
│   ├── go.md
│   ├── htmx.md
│   ├── css.md
│   ├── html.md
│   └── makefile.md
├── patterns/                       ← concrete, copyable implementation patterns
│   ├── go-project-layout.md
│   ├── go-http-server.md
│   ├── go-sqlite.md
│   ├── go-auth-sessions.md
│   ├── go-errors-logging.md
│   ├── go-testing.md
│   ├── go-performance.md
│   ├── go-cli.md
│   └── htmx-server-rendering.md
├── operations/                     ← how projects run in production
│   ├── web-application.md
│   ├── cli-release.md
│   └── ci.md
└── checklists/                     ← definition of done per project type
    ├── web-application.md
    ├── cli-tool.md
    └── library.md
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

- **Adversarial review before every tagged release:** independent reviewers hunt
  cross-document contradictions, trace every canonical snippet's mechanics end to end,
  and verify factual claims against upstream sources (Go, htmx, scs, SQLite, systemd,
  Caddy) — repeated until **two consecutive passes find zero defects**.
  Last full run: 2026-08-11, covering the STYLE.md addition
  (6 rounds, 17 defects fixed, converged at two consecutive zero-defect passes).
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
