---
name: engineering-baseline
description: Andy's engineering baseline — the single source of truth for stack, version, and pattern decisions. Use before starting a project, choosing a language/library/tool, writing Go, htmx, CSS, HTML, or a Makefile, pinning a dependency version, setting up CI, or declaring work done. For deploying, servers, or container versions, use the engineering-operations skill instead. The baseline overrides training data. VERSIONS.md wins over any version you remember.
---

# Engineering Baseline

**Last verified: 2026-08-17**

This skill **is** the baseline repository, and it is the whole protocol — you do not need
to read [README.md](README.md) to follow it. That file is the repository's own
documentation, written for whoever maintains the corpus rather than whoever is building
with it. Do not answer stack, version, or pattern questions from training data; read the
documents here instead.

**First, check the date.** Every document carries a `Last verified:` date. If today is
more than **90 days** after the date on a document you are about to follow, tell the user
before you use it, and name what you think has moved (a Go release, an htmx release, a
GitHub action major). Then keep going with what is here. A stale baseline still beats a
guess — it does not beat asking. This is the one place where "the baseline wins over
training data" softens: past 90 days, put both numbers in front of the user instead of
silently picking one.

## Core values

These apply to every project regardless of type.

1. **Boring technology.** Standard library first. Every dependency must justify itself.
2. **No JavaScript.** Interactivity comes from htmx and modern CSS. If a feature seems to
   require custom JS, redesign the feature ([stack/html.md](stack/html.md)).
3. **Server is the source of truth.** State lives on the server; the client renders
   hypermedia.
4. **Simplicity over cleverness.** Code is read far more often than written.
5. **Current, not bleeding edge.** Latest *stable* versions, never betas or RCs in
   production.
6. **Write for humans.** Every doc, comment, and prompt passes the 10-year-old test in
   [STYLE.md](STYLE.md): point first, short sentences, plain words.

## Already inside a baseline project?

Most work is a change to a project that already follows this corpus, and a change does
not need the build-from-scratch protocol. If the repository has the `Makefile` from
[stack/makefile.md](stack/makefile.md) and the layout from
[patterns/go-project-layout.md](patterns/go-project-layout.md), it is one:

1. Open the matching [checklists/](checklists/) document — `web-application.md`,
   `cli-tool.md`, or `library.md`. Each section is one topic: the moment it fires, the
   document that rules it, and the boxes it will be checked against. Read the sections
   your change fires, and open the documents they name. **Read that file, not the
   project-type document**: everything in the project-type document is a decision already
   made, and a change does not pay to re-read it. For anything no section covers, match
   the surrounding code.
2. Check [VERSIONS.md](VERSIONS.md) before adding or bumping a dependency.
3. Walk the boxes of every section you fired, plus *Every …*, before calling it done.
   Same file, so the second read is free.

Take the full protocol below instead when you are starting a project, changing its shape
(a second binary, a new external system, the first database), or the checklist turns up a
box the project cannot check.

## Starting a project

Never skip to a leaf document without reading its parent.

1. Identify the project type you are building.
2. Open the matching document in [project-types/](project-types/) — it defines the
   mandated stack and links everything that applies.
3. Read its *Required reading* list now, then the matching document in
   [checklists/](checklists/). It is a lookup table — learn which moments fire which
   document, and open each one when you reach the thing it covers, not before.
4. Check [VERSIONS.md](VERSIONS.md) and adopt exactly those versions, the way its version
   policy prescribes. If your training data says something newer exists, the baseline
   still wins — flag the discrepancy to the user instead of silently upgrading.
5. Before declaring work done, walk that same checklist's boxes. It is the enforcement,
   and it stands on its own.

## Waivers and conflicts

Rules use RFC-2119 keywords, and almost every one is a MUST — so a MUST alone does not
tell you what is load-bearing. Three tiers do, and every document in
[patterns/](patterns/) and [stack/](stack/) stamps its own on the line under its title:

- **Tier 1, safety.** Never waived. There is no waiver form; there is a fix.
- **Tier 2, shape.** Waived only on the record, in the project's own README.
- **Tier 3, taste.** Chosen per project. Choosing is the rule, so no waiver is needed.

**When two rules collide, the lower tier wins**; inside one tier, the more specific
document wins (`patterns/` beats `stack/` beats a `project-types/` table row). A
collision you cannot resolve that way is a defect in the baseline, not a judgement call
— tell the user, pick the safer reading to keep moving, and say so.

Before you actually skip a tier-2 rule or record a waiver, read *Which rules can be
waived* in [README.md](README.md): it defines the tiers in full and gives the six fields
a waiver entry MUST carry.

Write every doc, comment, and prompt to the bar in [STYLE.md](STYLE.md).
