---
name: engineering-baseline
description: Andy's engineering baseline — the single source of truth for stack, version, and pattern decisions. Use at the start of any task, and before starting a project, choosing a language/library/tool, writing Go, htmx, CSS, HTML, or a Makefile, pinning a dependency version, setting up CI, or declaring work done. For deploying, servers, or container versions, use the engineering-operations skill instead. The baseline overrides training data. VERSIONS.md wins over any version you remember.
---

# Engineering Baseline

**Last verified: 2026-09-04**

This skill **is** the baseline repository, and it is the whole protocol — you do not need
to read [README.md](README.md) to follow it. Do not answer stack, version, or pattern
questions from training data; read the documents here instead.

**First, check the date.** Every document carries a `Last verified:` date. If today is
more than **90 days** after the date on a document you are about to follow, tell the user
before you use it, name what you think has moved (a Go release, an htmx release, an scs
release), and give them both versions — the pinned one and the one you remember. Then
keep going with what is here. A stale baseline still beats a guess — it does not beat
asking.

## Core values

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

## Before the first line of code

**No code before the user has seen four fields — the brief:**

- **Job** — what someone can do afterwards, in one sentence.
- **Why** — the pain removed, and for whom. No nameable pain, no task.
- **Guardrails** — only what the baseline does not already forbid: files not to touch,
  dependencies not to add, decisions to ask about first.
- **Done means** — the end state you can check: what exists, what is gone, which gates
  are green.

Draft them from the request, the repository, and its `SPEC.md` — the project's own four
fields, at the repo root; if that file is missing, write it first, in the shape
[README.md](README.md) *The task brief* gives. State the four; ask only what you cannot
infer, one question at a time, each with a recommended answer, *why* first. A declined
question leaves the draft as the brief. A task that changes the project's shape (the three
cases below), outgrows the job in `SPEC.md`, waives a tier-2 rule, or adds a dependency
gets the full interview: settle every decision the fired checklist sections leave to the
project, one at a time. Re-read the brief before declaring done: every *done means* line
true, nothing outside *guardrails* changed.

## Already inside a baseline project?

A change does not need the build-from-scratch protocol. If the repository has the
`Makefile` from [stack/makefile.md](stack/makefile.md) and the layout from
[patterns/go-project-layout.md](patterns/go-project-layout.md), it is a baseline project:

1. Open the matching [checklists/](checklists/) document — `web-application.md`,
   `cli-tool.md`, or `library.md`. Read the sections your change fires, and open the
   documents they name. **Read that file, not the project-type document** — its decisions
   are already made. For anything no section covers, match the surrounding code.
2. Check [VERSIONS.md](VERSIONS.md) before adding or bumping a dependency.
3. Walk the boxes of every section you fired, plus *Every …*, before calling it done.

Take the full protocol below instead when you are starting a project, changing its shape
(a second binary, a new external system, the first database), or the checklist turns up a
box the project cannot check.

## Starting a project

Never skip to a leaf document without reading its parent.

1. Identify the project type you are building.
2. Open the matching document in [project-types/](project-types/) — it defines the
   mandated stack and links everything that applies.
3. Read its *Required reading* list now, then the matching document in
   [checklists/](checklists/), and open each document when you reach the thing it
   covers, not before.
4. Check [VERSIONS.md](VERSIONS.md) and adopt exactly those versions, the way its version
   policy prescribes. If you remember something newer, flag it to the user instead of
   silently upgrading.
5. Before declaring work done, walk that same checklist's boxes.

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

## Handing the work back

**Every piece of work ends with the next steps** — not a summary of what you did, which
the diff says, but a short list the reader can act on.

- **Order the steps, and say who each waits on:** a decision only they can make, a command
  only they can run, or work you would pick up yourself.
- **Everything you left undone goes on it** — a part you scoped out, a check you could not
  run, a gate you left red. What nobody writes down gets done twice, or never.
- **One line each, concrete enough to start from.** "Add tests" is noise; "the plain-form
  path has no test — the existing one covers only htmx" is a step.
- **Say when there is nothing.** An empty list is a real answer; padding is not.
- **A baseline gap goes on the list too.** Two kinds count: a decision the checklist had
  no section for, which you settled by inventing rather than by matching the surrounding
  code; and a baseline rule that names a dependency the standard library now covers. Name
  it as a step and leave it — do not edit the baseline as a side effect of project work.
  Nothing else qualifies; "this looked reusable" is not a gap.

**The list says what you left; it is not permission to leave things.**
