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

- **Last verified:** 2026-08-17
- **Format:** Markdown only, plus the MIT `LICENSE`. No code, no CI, no build
  steps. Documents are the product.
  The one piece of tooling is the root `Makefile`, which installs the baseline into
  Claude Code (see below) — it builds nothing.

## How to use this repository (AI agents)

Follow this protocol top-down. Never skip to a leaf document without reading its parent.

1. **Identify the project type** you are building (e.g. "web application").
2. **Open the matching document in [`project-types/`](project-types/).**
   It defines the mandated stack and links to everything that applies.
3. **Read its *Required reading* list now** — the [`stack/`](stack/) and
   [`patterns/`](patterns/) documents that apply to every project of that type. The rest
   of the corpus sits below it in a table indexed by trigger, one row per moment a
   document starts to matter. Open those rows as you hit them, not up front.
4. **Check [`VERSIONS.md`](VERSIONS.md)** and adopt exactly those versions, the way its
   version policy prescribes (e.g. `go 1.26` in `go.mod`, never a pinned toolchain patch). If a version in
   your training data is newer than what is listed here, the baseline wins — flag the
   discrepancy to the user instead of silently upgrading.
5. **Before declaring work done,** walk the matching document in [`checklists/`](checklists/).
   The checklist is the enforcement: it stands on its own, and it names the document
   behind every box you cannot check from memory.

Rules in these documents use RFC-2119 style keywords: **MUST**, **MUST NOT**, **SHOULD**, **MAY**.
Which of them may be waived, and how a waiver is recorded, is defined in
[Which rules can be waived](#which-rules-can-be-waived).

**Check the dates before you trust any of it.** Every document carries a
`Last verified:` date. If today is more than **90 days** after that date, say so to the
user before following the document, and name what you think has moved (a Go release, an
htmx release, an action major). A stale baseline still beats a guess — it does not beat
asking. This is the one place where "the baseline wins over training data" softens: past
90 days, put both numbers in front of the user instead of silently picking one.

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
│   ├── glossary.md
│   ├── go-auth-sessions.md
│   ├── go-cli.md
│   ├── go-config.md
│   ├── go-errors-logging.md
│   ├── go-forms-validation.md
│   ├── go-http-client.md
│   ├── go-http-server.md
│   ├── go-library.md
│   ├── go-llm-adapter.md
│   ├── go-performance.md
│   ├── go-ports-adapters.md
│   ├── go-project-layout.md
│   ├── go-sqlite.md
│   ├── go-testing.md
│   ├── htmx-live-updates.md
│   ├── htmx-server-rendering.md
│   ├── local-https.md
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
├── VERIFICATION.md                 ← the tag gate, and what every review run found
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

## Which rules can be waived

Almost every rule here is a MUST, so a MUST alone does not tell you what is
load-bearing. These three tiers do. They are the reading order when two rules collide
and the answer to "can we skip this one?".

**Tier 1 — Safety. Never waived.** A project that cannot meet one of these does not
ship. Everything under *Security* in the checklists (CSRF, escaping user input,
parameterized SQL, session cookie flags, password hashing, request body caps, the ops
listener never proxied), the SQLite pragmas and the single-writer pool
([patterns/go-sqlite.md](patterns/go-sqlite.md)), and any version pin whose note names a
security fix. Dropping one of these loses data, leaks it, or hands over an account.
There is no waiver form for a tier-1 rule; there is a fix.

**Tier 2 — Shape. Waived only on the record.** The mandated stack and the structural
patterns: no framework, no hand-written JavaScript, the project layout, config
precedence, the error and logging conventions, the CI gates, the testing strategy. These
are what make every project here interchangeable — an agent that knows one knows all of
them. Waiving one is a real decision with a real cost, so it gets written down in the
format below.

**Tier 3 — Taste. Chosen per project.** The rules the documents already frame as a
choice: which surface style ([patterns/css-surfaces.md](patterns/css-surfaces.md)),
whether the app is installable ([patterns/pwa.md](patterns/pwa.md)), whether a developer
can reach it from a phone over HTTPS ([patterns/local-https.md](patterns/local-https.md)),
whether the project
keeps a `GLOSSARY.md` ([patterns/glossary.md](patterns/glossary.md)), whether a CLI grows
a `-json` flag, whether there is a brand web font. Pick one, name it in `DESIGN.md` or
the README, and stay consistent. No waiver needed — choosing is the rule.

**When two rules collide,** the lower tier wins. Inside one tier, the more specific
document wins: a `patterns/` rule beats a `stack/` rule, which beats a `project-types/`
table row. **A collision you cannot resolve that way is a defect in this repository,
not a judgement call** — tell the user, pick the safer reading to keep moving, and fix
the corpus so the next reader never meets it.

**Recording a waiver.** A tier-2 waiver lives in the project's own README, in a section
a reader can find (`## Waived baseline rules` when the list is only waivers,
`## Baseline deviations` when conformance notes sit beside them). **The six fields are
the rule, not the heading:**

```markdown
- **No hand-written JavaScript** ([stack/html.md](...)) — waived 2026-08-15 by Andy.
  The barcode scanner needs `getUserMedia`, which has no hypermedia equivalent.
  Scoped to `web/static/js/scan.js`, 40 lines, no build step, CSP updated to match.
```

Every entry states the rule, the document, the date, who decided, why in one sentence,
and what contains the damage. The date and the decider are what a waiver is usually
missing: without them nobody can tell a considered exception from a two-year-old
shortcut nobody owns. **Do not label a waiver anything else.** A rule the project meets
by a different route is conformance, and a pattern the project never reaches is
unexercised — say which, because a reader hunting for gaps counts every bullet in that
section as one. "We didn't get to it" is not a waiver either; that is an open task, and
it belongs in the tracker.

## Quality bar & verification

Two mechanisms, and a release needs both.

- **Adversarial review** hunts cross-document contradictions, traces every canonical
  snippet's mechanics, and checks facts against upstream sources — repeated until
  two consecutive passes find zero defects.
- **The reference implementation is the executable check.**
  [baseline-reference](https://github.com/andygeiss/baseline-reference) implements
  these rules end to end. It MUST be synced to every tagged release, and its
  `./verify.sh` MUST pass against the commit being tagged. When a rule is ambiguous,
  the reference resolves it.

The standard, the tag gate, and what every run found live in
[VERIFICATION.md](VERIFICATION.md). Current state: last run 2026-08-17, which
added the LLM adapter pattern and the rule for retiring one, and found seventeen
defects over twelve passes — three of them introduced by its own fixes and caught
by the pass after. The reference is Go Chat, a chat application with a
command-line client and an assistant you mention in a room, and `verify.sh` is
green.

## Maintenance protocol (humans)

- Every document carries a `Last verified:` date. Re-verify at least **every 3 months**,
  and always after a major release of Go (Feb/Aug) or htmx. Past 90 days an agent stops
  treating the document as authoritative and says so — that warning is the reminder,
  and the only way to clear it is a real re-verification.
- **Before tagging, walk the gate in [VERIFICATION.md](VERIFICATION.md).** Two clean
  adversarial passes, the reference synced, `./verify.sh` green against the commit being
  tagged, and the run written into the log. A release that skips the reference is not a
  release.
- When updating a version: update `VERSIONS.md` first, then any stack document that
  references behavior of that version, then bump the `Last verified:` dates.
- **After moving anything out of this repository, sweep every consumer.** The
  operations split dropped facts its readers still needed. An extraction is not done
  when the file moves; it is done when nothing left behind still depends on it —
  the same sweep *Retiring a pattern* spells out below.
- New recurring decision in a project? Extract it into a pattern document here —
  the whole point is to never solve the same problem twice.

### Retiring a pattern

Documents arrive and never leave, and a corpus that only grows eventually costs
more to re-verify than it saves. Every pattern is a standing bill: a re-read
every ninety days, a place in the trigger table, and one more thing an agent may
have to hold. Retiring one is ordinary maintenance, not failure.

**Three signals. Any one is enough.**

1. **Its subject is gone.** The technology, the API, or the shape it describes is
   no longer in the stack. The rule has nothing left to govern.
2. **Nothing has reached it in a year.** Not one project hit its trigger, and the
   reference never exercised it. One project not reaching a pattern means nothing
   — that is *unexercised*, and it is normal. Every project missing it for a year
   is the signal.
3. **Another document now says the same thing.** Two documents on one subject is
   a collision waiting to happen; merge them and retire the loser.

**Tier 1 is retired only on signal 1.** A safety rule nobody happened to exercise
is not a safety rule nobody needs — disuse is never a reason to drop CSRF,
escaping, the SQLite pragmas, or a pin that names a security fix.

**A half-removed pattern is worse than a kept one**, because a dangling link is a
dead end for an agent mid-task. Removing one is therefore a sweep, in this order:

1. **Write down why first**, in [VERIFICATION.md](VERIFICATION.md). That entry is
   the tombstone — dated, and saying what replaced the document. There are no
   stub files; the run log is where a retired name stays findable.
2. **Move anything still true** to the document that now owns it. Retirement is
   not a way to lose a rule by accident.
3. **Delete the file, then sweep every consumer** — `git grep` its filename and
   fix each hit: this README's tree, the [`project-types/`](project-types/)
   trigger tables, the [`checklists/`](checklists/) boxes, cross-links in other
   patterns, and the reference implementation with its `SPEC.md`.
4. **Ship it as a breaking change.** The corpus loses a rule, so the commit
   carries `!` and the release is a major — the operations split was v3.0.0 for
   exactly this reason.
