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
  The one piece of tooling is the root `Makefile`: it installs the baseline into
  Claude Code, measures its read paths against the budgets below (`make tokens`),
  and checks its own shape (`make structure`) — it builds nothing.

## How to use this repository

**AI agents: read [SKILL.md](SKILL.md), not this file.** It carries the whole protocol —
the core values, the reading order, the date check, and the tier summary — in a fifth of
the tokens, because everything below is written for whoever maintains the corpus rather
than whoever is building with it. The one section here an agent ever needs is
[Which rules can be waived](#which-rules-can-be-waived), and SKILL.md links straight to
it at the moment a rule is about to be skipped.

Keeping the protocol in one file and not two is deliberate. It used to live in both, and
a protocol stated twice is a protocol that drifts in one of the copies — the same reason
[`patterns/security-headers.md`](patterns/security-headers.md) refuses to let any other
document restate the CSP.

For a human reading along: the corpus is a tree. [`project-types/`](project-types/) is
the entry point per kind of project — a short *Required reading* list and the decisions
made before the first line of code. [`checklists/`](checklists/) is everything after
that, one section per topic: **the moment it fires, the [`stack/`](stack/) or
[`patterns/`](patterns/) document that rules it, and the boxes it will be checked
against.** Routing and the definition of done are one file because a change to an
existing project reads the sections it fires and nothing else — the most common thing
anyone does here — and because a trigger pointing at a document no box ever checks is how
a rule goes missing. It still stands on its own.

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
├── checklists/                     ← triggers + definition of done per project type
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
│   ├── go-authorization.md
│   ├── go-background-work.md
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
│   ├── llm-prompting.md
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

The six that apply to every project regardless of type — boring technology, no
JavaScript, server as the source of truth, simplicity over cleverness, current rather
than bleeding edge, and writing for humans — are stated in full in
[SKILL.md](SKILL.md) *Core values*, so that an agent gets them without reading this
file. They are not repeated here for the same reason the protocol is not.

## Which rules can be waived

Almost every rule here is a MUST, so a MUST alone does not tell you what is
load-bearing. These three tiers do. They are the reading order when two rules collide
and the answer to "can we skip this one?".

**Every document in [`patterns/`](patterns/) and [`stack/`](stack/) stamps its tier on
the line under its title** — `**Tier 2** (shape — waived only on the record) · Last
verified: 2026-08-17` — and names, in its own words, any rule inside it that sits in a
different tier. That stamp is the local
answer for an agent that opened one document mid-task; this section is the definition
behind it. When the two disagree, this section wins and the document is the defect.

**Tier 1 — Safety. Never waived.** A project that cannot meet one of these does not ship.
**The test is what the rule protects, not where it is written down: a rule is tier 1 when
dropping it loses data, leaks it, or hands over an account.** Apply the test; the list
below is what it currently catches, not the definition.

- The headers and the request surface — CSRF, escaping user input, request body caps, the
  security-header policy, the ops listener never proxied
  ([patterns/security-headers.md](patterns/security-headers.md),
  [patterns/go-http-server.md](patterns/go-http-server.md)).
- Everything about who is signed in: session cookie flags, renewal on login and password
  change, password hashing, auth rate limiting, constant-time login, and every
  machine-token rule ([patterns/go-auth-sessions.md](patterns/go-auth-sessions.md)).
- Parameterized SQL, the SQLite pragmas, and the single-writer pool
  ([patterns/go-sqlite.md](patterns/go-sqlite.md)).
- Any version pin whose note names a security fix.
- Every rule about how a secret is handled: a secret arrives as a file and `LogValue`
  keeps it out of the logs ([patterns/go-config.md](patterns/go-config.md) *Secrets*), a
  secret never arrives as a flag *value* ([patterns/go-cli.md](patterns/go-cli.md)), and
  `.env` is gitignored and never used in production
  ([stack/makefile.md](stack/makefile.md) rule 6).

**The checklists mark this, they do not imply it.** A trigger section that is wholly
tier 1 says so under its heading; where only some of a section's boxes are, the
checklist's preamble names them. Nothing is tier 1 because of the section it landed in —
that positional definition died when routing and the definition of done became one file
and the security boxes scattered across the topics that fire them.

There is no waiver form for a tier-1 rule; there is a fix. **A rule that meets the test
but is not listed here is still tier 1** — say so, and fix this section.

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
[VERIFICATION.md](VERIFICATION.md) — which also carries the running list of changes
that have not been through a run yet. **Read its *Owed* section before tagging:** it is
the one place that says whether the gate is currently open. Keeping the current state
there and not here is deliberate — a status paragraph in two files is a status
paragraph that goes stale in one of them.

## Maintenance protocol (humans)

- Every document carries a `Last verified:` date. Re-verify at least **every 3 months**,
  and always after a major release of Go (Feb/Aug) or htmx. Past 90 days an agent stops
  treating the document as authoritative and says so — that warning is the reminder,
  and the only way to clear it is a real re-verification.
- **Run `make structure` and `make tokens` on any change to the corpus.** The first
  checks the two claims this repository makes about its own shape — the tree above
  against the real directory, and the tier stamp on every [`patterns/`](patterns/) and
  [`stack/`](stack/) document against the one format *Which rules can be waived* prints.
  Both exit non-zero, so a review pass gates on them instead of proofreading them. A
  claim of mechanical checkability that nothing checks is how a tree entry sits one line
  out of place through ten readings.
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
- **[VERIFICATION.md](VERIFICATION.md) keeps its three newest runs in full**; older ones
  compress into *Earlier runs*, keeping the counts and the findings a future run would
  otherwise re-derive. It is the one file that grows by construction — one narrative per
  release, forever — and it is off every read path, so the cost it accumulates is the
  re-reading, not the tokens. The full narratives stay in git history.

### Size budgets

**Budget the read path, never the repository.** The repository total is vanity: this file
and [VERIFICATION.md](VERIFICATION.md) are an eighth of it and sit on no read path at
all, while the floor every web application pays before its first line of code is the
number that actually hurts. `make tokens` prints every budget below, plus the repository
total as a report it never gates on.

Two budgets cap a single document:

- **A [`patterns/`](patterns/) or [`stack/`](stack/) document stays under 3,800 tokens,
  prose and fenced code together.** One number, because a reader pays for both and a
  split budget only measures which side of the fence the author put the answer on — the
  first sweep to move code into prose passed a code cap and blew a prose cap without
  changing what anyone reads. `make tokens` still prints the split, as a diagnosis: past
  budget on prose usually means a document that owns two subjects, or prose that is
  arguing when it should be ruling; past budget on code means *Write to the reader's
  competence* below. **Aim at 1,800 for a new document;** 3,800 is the ceiling, not the
  target.
- **A checklist stays under 4,300 tokens.** It is paid whole by every project of that
  type, on every change and at every milestone — the most-paid document in the corpus,
  and the reason it was worth folding the router into rather than beside it.

Three budgets cap a path somebody walks:

- **The floor stays under 19,500 tokens** — `SKILL.md`, `VERSIONS.md`, the project-type
  document, its checklist, and every *Required reading* entry. That is what an agent pays
  before writing a line, so adding a document to a *Required reading* list means moving
  another one to a trigger section. A document belongs on that list only if it changes a
  decision made *before* the first line of code; everything you can read at the moment
  you write the thing is a trigger section in the checklist.
- **A change stays under 7,000 tokens** — `SKILL.md`, `VERSIONS.md`, and the checklist.
  This is the most common thing anyone does here and therefore the number paid most
  often.
- **Reach is reported, not budgeted.** Every document a project type can get to is a
  ceiling no build ever pays, because no project fires every trigger. `make tokens` ranks
  the heaviest documents on each reach path and marks whether every project of that type
  pays them, because **size alone does not say what is worth shrinking — size times how
  often it is read does.** How often is the maintainer's judgement; the report is what
  that judgement gets applied to.

And two rules keep all of them down:

- **Rationale earns one sentence per rule.** The evidence is a URL under *Facts
  verified*, and the argument behind the decision belongs in
  [VERIFICATION.md](VERIFICATION.md) — that file is the record of *why* the corpus says
  what it says, and it is read by whoever is auditing a rule, not by whoever is
  following it. A document that re-litigates its own history bills every future reader
  for a debate that is already settled. **VERIFICATION.md is the sink, and it is free:**
  moving an argument there costs nothing on any read path.
- **Write to the reader's competence.** The reader is a capable Go engineer, not a blank
  slate, and every line spent on what it already knows is a line it pays to skip. The test
  for a snippet is one question: *would a competent engineer get this wrong from the rule
  sentence alone?* A jittered backoff, a `time.Timer` raced against `ctx.Done()`, a table
  test — no, so the contract is the payload and the body is overhead. `http.DefaultClient`
  having no timeout, `Do` returning `nil` for a 500, a nil `GetBody` replaying an empty
  body the server accepts — yes, so those stay in code. **The same test governs an
  anti-pattern list:** keep the ❌ that names something you would otherwise reach for
  (resty, viper, an icon font, Google Fonts) or carries a fact stated nowhere else; delete
  the ❌ that restates a rule the document already made, which is duplication inside a
  single read path and the kind that gets paid twice.

**Duplication is only expensive when both copies land in one context.** The three
checklists share hundreds of phrases and the three project-type documents share hundreds
more — that costs nothing, because no task ever reads two of them. Do not factor out a
shared file to fix it: an agent would then read two files for the same total, and a
checklist would stop standing on its own. Duplication *within* a read path — a pattern
restating what its project-type document already said — is the kind that gets paid twice
and the kind to hunt.

The budgets are shape rules, so a document over one is waivable on the record like any
other — but the waiver goes in [VERIFICATION.md](VERIFICATION.md), because the cost
lands on this repository rather than on a project built from it.

### Writing a checklist

**One box, one check.** A box that needs two answers is two boxes: a box holding six
conditions gets ticked while three of them fail. Where several checks share a narrower
scope inside a section, the scope is a bold bullet and the checks sit under it.

**One section per topic, and the section is the trigger.** Its heading names the moment
in gerund form, so it reads as *when you are about to…* on the way in and *if the project
has…* on the way out; the line under it names the document and what is in it; the boxes
follow. A new pattern is not wired up until it has a section here — that is the check
that a document nothing points at cannot ship again. A section MAY carry no box, where
the document rules something no milestone can verify; say so in the section rather than
inventing a box to fill the shape.

Boxes that fire for every project of the type go under *Every …* at the top, ahead of the
triggers.

**Name documents as bare repository-root paths**, not as markdown links. The link syntax
spends a sixth of a router-sized table restating a path it just printed, an agent opens
either one the same way, and `make tokens` reads these paths to compute the reach path.

This guidance lives here rather than in the checklists themselves because it is an
instruction to whoever *adds* a box, and a checklist is paid in full by every project of
its type on every change. Guidance for authors belongs in the maintainer's file.

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
   patterns, and the reference implementation with its `SPEC.md`. `make structure`
   catches the tree on its own, so the grep is for the other five.
4. **Ship it as a breaking change.** The corpus loses a rule, so the commit
   carries `!` and the release is a major — the operations split was v3.0.0 for
   exactly this reason.
