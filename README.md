# Engineering Baseline

**Single source of truth for how I build software.** This repository closes the gap
between an LLM's training data and the current state of the art. AI agents working on
any of my projects MUST consult this baseline before making stack, version, or pattern
decisions — do not rely on training data for anything covered here.

- **Owner:** Andy Geiss
- **Last verified:** 2026-08-10
- **Format:** Markdown only. No code, no tooling, no build steps. Documents are the product.

## How to use this repository (AI agents)

Follow this protocol top-down. Never skip to a leaf document without reading its parent.

1. **Identify the project type** you are building (e.g. "web application").
2. **Open the matching document in [`project-types/`](project-types/).**
   It defines the mandated stack and links to everything that applies.
3. **Read the linked [`stack/`](stack/) documents** for language/tool conventions
   and the linked [`patterns/`](patterns/) documents for concrete implementation patterns.
4. **Check [`VERSIONS.md`](VERSIONS.md)** and pin exactly those versions. If a version in
   your training data is newer than what is listed here, the baseline wins — flag the
   discrepancy to the user instead of silently upgrading.
5. **Before declaring work done,** walk the matching document in [`checklists/`](checklists/).

Rules in these documents use RFC-2119 style keywords: **MUST**, **MUST NOT**, **SHOULD**, **MAY**.

## Repository structure

```
baseline/
├── README.md                       ← you are here: navigation protocol
├── VERSIONS.md                     ← pinned versions, dated, with sources
├── project-types/                  ← entry point per kind of project
│   └── web-application.md
├── stack/                          ← per-technology conventions
│   ├── go.md
│   ├── htmx.md
│   ├── css.md
│   └── html.md
├── patterns/                       ← concrete, copyable implementation patterns
│   ├── go-project-layout.md
│   ├── go-http-server.md
│   ├── go-errors-logging.md
│   ├── go-testing.md
│   └── htmx-server-rendering.md
└── checklists/                     ← definition of done per project type
    └── web-application.md
```

## Core engineering values

These apply to every project regardless of type:

1. **Boring technology.** Standard library first. Every dependency must justify itself.
2. **No JavaScript.** Interactivity comes from htmx and modern CSS. If a feature seems
   to require custom JS, redesign the feature (see [stack/html.md](stack/html.md)).
3. **Server is the source of truth.** State lives on the server; the client renders hypermedia.
4. **Simplicity over cleverness.** Code is read far more often than written.
5. **Current, not bleeding edge.** Latest *stable* versions, never betas/RCs in production.

## Maintenance protocol (humans)

- Every document carries a `Last verified:` date. Re-verify at least **every 3 months**,
  and always after a major release of Go (Feb/Aug) or htmx.
- When updating a version: update `VERSIONS.md` first, then any stack document that
  references behavior of that version, then bump the `Last verified:` dates.
- New recurring decision in a project? Extract it into a pattern document here —
  the whole point is to never solve the same problem twice.
