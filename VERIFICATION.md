# Verification Record

**Last verified: 2026-09-08**

How this repository proves it is right. The README states the standard in a
paragraph; this file holds the gate and the standing arguments behind it. What
each run found is on its tag's
[release page](https://github.com/andygeiss/baseline/releases); the run log that
lived here until v4.6.0, and grew back under *Owed* until v5.2.0, is in git history.
It is written for whoever is about to tag a release, or is auditing whether a rule
was ever actually checked.

## What a review run is

A run has two halves, and a release needs both.

1. **The adversarial half.** Independent reviewers hunt cross-document
   contradictions, trace every canonical snippet's mechanics end to end, and
   check factual claims against upstream sources (Go, htmx, scs, SQLite). They
   repeat until **two consecutive passes find nothing high and nothing medium**,
   as *Grading a finding* below defines the two. Reading is not
   enough on its own: every canonical Go snippet gets compiled and run through
   `gofmt`, `go vet`, `go fix -diff`, `staticcheck`, and `govulncheck`, the
   canonical `Makefile` runs end to end under GNU Make 3.81, the version macOS's
   Command Line Tools ship, and every measured color claim gets recomputed from its
   oklch values. **One reviewer builds from the documents alone:** a new project
   for each project type the change reaches, written from this corpus and nothing
   else — not the reference, not another project — and using every changed rule a
   build can exercise. Its `make check` and `make ci` are green, or what stopped
   them is a high finding. What no build can exercise, the pass reads. A build that
   could not run is a pass that did not happen.
2. **The empirical half.** [baseline-reference](https://github.com/andygeiss/baseline-reference)
   implements the corpus end to end. It is synced to the change, and its
   `./verify.sh` runs every mechanical gate, then boots the real binary and
   smoke-tests the running application. This is the only half that catches rules
   that are each correct and do not compose.

The two halves catch different bugs. Document review found a stale
`X-Forwarded-For` fact (v3.0.0); only a running application would have found a rule
that contradicts another one nothing points at.

## Grading a finding

One question grades every finding: **what does a project end up with when its agent
follows this text to the letter?**

- **High** — something that loses data, leaks it, or hands over an account. Or
  nothing: a snippet that does not compile, a recipe that does not run.
- **Medium** — something wrong that no gate catches.
- **Low** — the right thing, at worst after `make fmt` or a gate's own message put
  it right.

**To the letter means the worst reading.** Where a sentence can be read two ways, two
documents answer one question differently, or a box and its rule differ, grade what
the worse reading builds. It is low when every reading builds the same thing. A box
that cites a rule stands for that whole rule, and a tier-1 rule no box checks is
graded as if nobody checked it.

**The reviewer grades,** and whoever fixes does not regrade; a finding is withdrawn
only on evidence that it is wrong. A finding in the reference is the reference's. A
claim nobody could check is not a finding: it is listed under *Owed* as unchecked.

**Maintainer text is graded by what a release may then ship.** That is this file, and
the README outside *Which rules can be waived* and *The task brief*, which projects
read.

**Evidence, or it is not a finding.** The command and its output, or the source and
the sentence that contradicts the claim.

**A low never holds a tag.** It is fixed in the run or listed under *Owed*. A fix made
after the last pass is unread: *Owed* names its commit, and the next run reads it.
Such a fix changes wording and nothing else. One that changes what a rule requires, a
snippet, a recipe, or any statement of a tier-1 rule — the rule, its header, its
README entry, its box — is read by a pass first, or the low stays listed.

## The tag gate

**No tag ships until the first four are true, and no release is finished until the
fifth is.** This is a gate, not a goal, and it has no override.

1. Two consecutive adversarial passes find nothing high and nothing medium, and in
   each of them the build from the documents alone is green. The passes read the
   changed documents and everything *Owed* lists as unread. `make structure` and
   `make tokens` exit 0, or the budget's waiver is on the record.
2. The reference implementation is synced to the change, and `./verify.sh` exits
   0 against the baseline commit its `SPEC.md` pins.
3. The reference's `SPEC.md` pins that commit and carries the four-field brief, and
   its own tag mirrors the baseline version.
4. **Nothing a project reads changed between the pinned commit and the tag.**
   `git diff --name-only <pin> <tag>` names this file and nothing else.
5. After the tag, its release page records the run, naming the reference release and
   the `verify.sh` result.

**A change that alters no rule, snippet or recipe skips the build:** a typo, a link
that moved. Condition 2 is its build.

**One change does not wait for *Owed*: a pin whose note names a security fix.** That
pin is tier 1, so it ships alone — the `VERSIONS.md` row and the places that pin sits,
nothing else — on a run over that diff. That run neither reads nor clears *Owed*. A
pin that cannot go green without changing a rule is not this exception.

**Condition 1 asked for zero defects until 2026-11-09, and six releases in a row
shipped without it.** v4.8.0 through v5.2.0 each went out on Andy's decision, each
recorded. On every change larger than a pin the count never reached zero: v5.2.0's
sixteen passes found 16, 14, 16, 11, 12, 12, 9, 9, 6, 6, 5, 6, 6, 9, 6 and 9, and a
count that adds a leak to a misplaced comma does not say when to stop. The condition
now counts only what a project would get wrong. **That is a different bar, not a
lower one.** v5.1.0's sixth round would have met the count. v5.2.0's last two passes
still fail it: pass 15 on two documents that answered one question differently, pass
16 on a socket that kept a private room's state. All seven builds from the documents
alone, in passes 10 to 16, were green through both, so the build is a floor and not
the proof. Decided by Andy, 2026-11-09.

**Conditions 2 and 4 were one sentence until 2026-08-18, and it was one no release
could meet.** It read "`./verify.sh` exits 0 against the exact baseline commit
being tagged" — but the run record then lived in this file and named the reference
commit, so the tagged commit could never be the one the reference pinned. The order
now: the rules commit, the reference synced and tagged against it, the *Owed* section
brought up to date, the tag, then the release page.

**Every release met that gate in substance and none met it literally.** v3.6.0
through v3.9.0 each pinned a commit that is not the tagged one, and the whole
difference is this file, every time — v3.6.0's two commits have identical trees.
Condition 4 now checks that directly instead of demanding commit identity: the
rules the reference verified are the rules being tagged, which was always the
thing worth gating. It is one command, so it is checkable rather than assumed.

**A release note that says "the reference was not re-synced" is not a waiver —
it is an unfinished release.** That sentence appeared in two consecutive runs
before this gate existed, which is why the gate exists. If the reference cannot
be synced, the tag waits.

## Owed: what the next run reads, and what is known and not fixed

**An entry here is a debt, not a story:** what is unread or unfixed, where, and since
when, in a line or two. What a pass found and fixed goes in the fix commit's body during
a run, and on the release page after the tag. The entries as they stood at v5.2.0,
narrative and measurements included, are in this file at that tag; the v5.2.0 run is on
its release page.

**This section says what the next run faces.** It reads everything under *Unread*.
Listing a finding under *Known, not fixed* does not waive it: a pass that reads its
document finds it again, and a high or a medium then holds the tag. An entry with no
grade is a decision or a note.

**While anything is listed under *Unread*, no new pattern lands** ([README.md](README.md)
*Maintenance protocol*). The last run's own wording fixes do not count.

### Unread, or read and never passed

- **`patterns/go-child-process.md`, whole,** with its section, its secret box and its
  vet box in `checklists/cli-tool.md`, the README's tier-1 clause for a child's
  secret, and the Unix sentences in `operations/ci.md`. New on 2026-10-04, in every
  tag since v5.1.0. Five rounds read it and none passed.
- **A CLI may serve the person who started it** — `project-types/cli-tool.md`, widened
  on 2026-10-09, on Andy's call.
- **`patterns/wasm-client.md`, whole,** with `patterns/go-auth-sessions.md`
  *Re-resolving a long-lived connection* and `patterns/go-authorization.md` rule 6. New
  in v5.2.0; sixteen passes read them and the last two did not pass. `a5975cb`, pass
  16's fixes, also touches the three checklists and the README's tier-1 list.
- **`aafa39f`, round four's fixes for v4.8.1** — `operations/ci.md`,
  `operations/cli-release.md`, `checklists/cli-tool.md`.
- **`7bd81fa`, round five's fixes for v5.0.0** — `stack/htmx.md`, `stack/html.md`,
  `patterns/go-file-uploads.md`, `patterns/go-http-client.md`,
  `patterns/go-http-server.md`, `patterns/go-background-work.md`,
  `patterns/htmx-server-rendering.md`, `patterns/htmx-live-updates.md`.
- **`bcbb2aa`, round six's fixes for v5.1.0, and `ab31e65`,** which dropped
  `StrictPragmas` to tier 2 on Andy's call — `patterns/go-sqlite.md`, the README's
  tier-1 list, and the preambles of two checklists.
- **`patterns/go-email.md`, whole.** The 2026-11-09 run read it four times and found a
  medium each time. `cbf0fcd` fixes the fourth, and no pass has read that. Its date did
  not move.
- **This file's *Grading a finding*, *The tag gate* and *Owed*, and the README
  paragraphs that go with them,** as rewritten from `24f5bcc` on. Two reviews read
  earlier versions and found 14 and 16 mediums. None has read this one.
- **Wording the 2026-11-09 run fixed after its last pass:** `cbf0fcd` in
  `patterns/go-data-deletion.md` and `patterns/htmx-lists.md`, and one sentence of
  `23bd353` in `patterns/time-and-dates.md`.

### Known, not fixed

- **Medium — the child-process pattern: ten findings from round five, 2026-10-09,**
  three of them medium, all in the tests the pattern prescribes. This file lists the
  ten at v5.2.0.
- **Medium — a CLI that listens on a port** gets none of the web application's
  cross-origin rules, server timeouts, or request-body cap (2026-10-09).
- **Medium — tier-1 rules that no box checks:**
  - a child's secret, in `checklists/web-application.md` (2026-10-04). Its only
    statement is the header of `patterns/go-child-process.md`.
  - closing `Rows`, `Stmt` and `Tx`, in either checklist, and the single-writer pool
    in the CLI's (2026-10-31).
  - no test sending a request off the machine (`patterns/go-testing.md`).
  - *Boost only pages* (`stack/htmx.md` rule 8), beyond file links and the program
    page (2026-10-27).
  - `FindCtx` treating expired rows as not found, and machine-token rule 6
    (`patterns/go-auth-sessions.md`).
  - the patch a security pin sets. No document owns that rule either.
- **Medium — boxes and headers that have drifted from their rule,** found on
  2026-11-09. Trim none before its conditions are in its rule:
  - The login box and the README check timing. `patterns/go-auth-sessions.md` asks for
    the identical message and the same time.
  - The logs box checks `Config.LogValue`. `patterns/go-config.md` *Secrets* also makes
    a secret its own type.
  - The header of `patterns/go-config.md` bans a secret in an environment variable
    outright. Its *Secrets* section scopes the ban to services, and
    `patterns/go-child-process.md` allows the child's own environment.
  - The preamble of `checklists/cli-tool.md` makes two rules tier 1 that
    `patterns/go-cli.md` and the README's list do not. A decision.
  - The `.env` boxes fire when the repository has a `.env`. `stack/makefile.md` rule 6
    asks for the gitignore line in the commit that adds the recipe.
- **Medium — `patterns/go-errors-logging.md` logs a person's name** in its canonical
  line, and its "Never log" list names neither a name nor an address.
  `patterns/go-email.md` and `patterns/go-ports-adapters.md` keep both out (2026-11-09).
- **Medium — htmx 4.0.0, the pinned version, empties the focused field on a 422 swap**
  when Enter submits the form. 4.0.1 does not, and `"defaultSettleDelay":0` avoids it
  (the 2026-11-09 build, Chromium).
- **Medium — `patterns/go-auth-sessions.md`, from the 2026-11-09 build:**
  - "Consider sessions of that user revoked on successful reset" reads as optional or
    as a duty, and names no mechanism and no box.
  - The session manager is built without `ErrorFunc`, so a store error goes to stderr
    unstructured. `operations/web-application.md` asks for structured logs on stdout.
  - "No user enumeration" covers the login only. The conflict example in
    `patterns/go-forms-validation.md` tells a stranger which addresses have accounts.
- **Medium — `stack/htmx.md` asks every request over 100 ms for an indicator,** and its
  box checks that. No canonical snippet carries one (the 2026-11-09 build).
- **Medium — `patterns/time-and-dates.md` bans `time.Local` everywhere.** A CLI runs
  on the reader's machine and has no other zone; the reference's calls `t.Local()`.
- **SQLite, left open by the v5.1.0 run, 2026-10-31:**
  - Medium — `go get -u ./...` in `operations/ci.md` raises `modernc.org/libc` past the
    version the driver's `go.mod` names, and nothing in the corpus holds it back.
  - Low — an empty database path is refused nowhere at the config edge; `openDB` fails
    only at the first query.
  - Low — a `..` through a symlink opens the file the OS means, but the snapshot is
    built from `filepath.Dir`, which folds it as text and lands elsewhere.
  - Low — Windows paths: rule 10 reads paths the Unix way and goes no further.
  - Medium — the snapshot fails on every restart after the day's first: `VACUUM INTO`
    refuses a file that exists, and a ticker runs once at boot. `patterns/go-sqlite.md`
    does not say its ticker prunes either; `patterns/go-data-deletion.md` now does
    (2026-11-09).
  - Unchecked — `TestLockWaitEndsAtTheDeadline` was never run against v1.58.0.
- **Low, in documents the 2026-11-09 run did not read whole:**
  - `stack/htmx.md`: a boosted request answered 204 pushes its URL and runs a view
    transition with nothing swapped, and no `hx-status` line covers 204 (Chromium).
  - `stack/htmx.md` rule 8 never names `template.HTML`; a header and a box do. Nothing
    defines "zero CSP violations in the browser console". The 1 MiB box drops the
    upload exception. The README's entries for uploads and for boost are wider and
    narrower than their documents.
  - `patterns/css-typography.md` calls `text-wrap: balance` Baseline Newly in three
    places; it turns Widely on 2026-11-13.
  - `patterns/htmx-live-updates.md` says its `AUTOINCREMENT` column is `go-sqlite.md`'s,
    which never mentions one, and that moving the viewport needs JavaScript, where
    htmx 4 has `scroll:` and `show:`.
  - `patterns/go-config.md`'s canonical config has no check for the log transport, and
    describes `ENV` as the log format only.
- **Low — no `Last verified:` date moved in v5.1.0 or v5.2.0** for what they read only
  where it changed: `stack/makefile.md`, `stack/go.md`, `stack/html.md`,
  `stack/htmx.md`, `patterns/go-project-layout.md`, `patterns/go-http-server.md`,
  `patterns/go-background-work.md`, `patterns/htmx-live-updates.md`,
  `patterns/go-sqlite.md`, `project-types/web-application.md`, the three
  `operations/` documents, the three checklists, `SKILL.md` and `VERSIONS.md`.
- **Unchecked — what htmx 4.0.0 does on Back and Forward after a boosted link** was
  run in Chromium only (2026-10-31).
- **Low — `govulncheck` reported GO-2026-5932** in `golang.org/x/crypto` v0.58.0 on
  2026-10-31: no fix released, and not called.
- **Decisions left to Andy:**
  - Scroll-driven animations are Baseline Newly since 2026-10-27;
    `patterns/css-motion.md` still keeps them out.
  - `stack/css.md` now exempts a `font-family` name from the feature rule, to keep
    `ui-monospace`. Dropping the name is the other fix.
  - `patterns/security-headers.md` is stamped tier 1, and its header places only some
    of its MUSTs. The ban on extra headers and the HSTS options read as tier 1 too.
  - `patterns/go-data-deletion.md` is stamped tier 1 as well, and its header does not
    place asking for the password again.
  - How many snapshots a binary keeps is the project's number. Whether
    `patterns/go-sqlite.md` should carry a default is open.
  - No poll re-renders a relative time. Whether `patterns/htmx-live-updates.md` should
    carry a region that does is open.
  - The outbox delete by address compares bytes; the corpus prescribes no way to
    normalise an address.
  - The neumorphic floors in `patterns/css-surfaces.md`, 6.2 and 3.3, hold unrounded;
    a tool fed the 8-bit colors reads 6.19 and 3.29.
  - "The re-check only reads" (`patterns/wasm-client.md` rule 6) was recorded in
    v5.2.0's pass 8 as Claude's decision, and never confirmed.
- **Pins behind upstream on 2026-11-09:** htmx 4.0.1 is npm's `next` since 2026-11-01,
  and `modernc.org/sqlite` v1.62.0 shipped on 2026-11-07. `VERSIONS.md` pins 4.0.0 and
  v1.61.0. Go 1.27.3, scs v2.9.0 and TinyGo 0.44.0 are current.
- **Low — `patterns/security-headers.md`'s `img-src` check reads the constant as text.**
  A second `img-src` directive ahead of the right one passes it, and a policy written
  with other spacing fails it (pass 3, 2026-11-10).
- **Low — commit subjects.** `STYLE.md` asks for the imperative; 65 of this
  repository's last 100 subjects are noun phrases.
- **Low — fifteen findings from the 2026-11-09 build, and the twenty decisions it had
  to invent,** in twelve documents this run did not read whole. They are spelled out in
  the body of the commit that added this line.

### The reference, behind this corpus

Found by the 2026-11-09 run. Condition 2 needs each one settled before the tag that
carries that run's changes:

- `web/static/css/app.css:141` still carries `scroll-behavior: smooth`.
- `cmd/server/mail.go` logs the recipient on a failed send, and
  `internal/smtpmail/smtpmail.go` wraps the address, and the relay's reply text, into
  its error.
- `internal/smtpmail` writes the body with no bare-CR replacement, and the message
  with no `Date`, `Message-ID` or `Content-Transfer-Encoding`.
- `internal/app/account.go` checks the password on account deletion with no rate limit.
- `internal/store/users.go` deletes the account in one statement, with no delete of
  outbox rows by address.
- `internal/store/outbox.go` keeps the body of a row it has sent or given up on.
- `web/templates/room.html`: the "Show older messages" control has no `id`, and no end
  marker takes its place on the last page.
- `internal/anthropic/anthropic.go` has no check for an answer cut short, and its
  header timeout sits below the budget.
- `internal/app/middleware_test.go` checks `img-src` by prefix.
- `cmd/server/main.go` removes only today's snapshot; older ones are never pruned.
- `web/static/css/app.css:438` and `:461` use `var(--step--1)`, which nothing defines.
- `web/static/css/app.css:490` and `:471` use `user-select: all` and `resize: vertical`,
  both Baseline Limited.

## Why the CSP is what it is

The standing record behind [patterns/security-headers.md](patterns/security-headers.md).
That document owns the policy and every rule; this section owns the argument, so an agent
following the policy never pays for it and an agent changing the policy can check its
work. **Add a row here when the policy changes.**

Every feature in the baseline, and what it needs:

| Feature | Needs | Covered by |
|---|---|---|
| htmx | `script-src 'self'` | `default-src`; htmx is self-hosted, no inline JS ([stack/htmx.md](stack/htmx.md)). |
| htmx indicators | nothing | htmx 4 adds its indicator styles as a constructed stylesheet, which the policy does not block (measured in Chromium, Firefox and WebKit). The canonical layout turns it off anyway, for the cascade and for reduced motion, and `app.css` owns those rules ([stack/htmx.md](stack/htmx.md)). |
| Mask icons | `img-src data:` | One of two directives a default policy would get wrong; the other is a WebAssembly client's `script-src`. |
| Self-hosted font | nothing | Same-origin `.woff2` ([patterns/css-typography.md](patterns/css-typography.md)). A third-party font host would need a `font-src` hole — one reason there isn't one. |
| Web app manifest | nothing | `manifest-src` falls back to `default-src`, and the manifest is same-origin ([patterns/pwa.md](patterns/pwa.md)). |
| View transitions, CSS motion | nothing | Pure CSS ([patterns/css-motion.md](patterns/css-motion.md)). |
| Forms | `form-action 'self'` | Already in the policy. |
| WebAssembly client | `script-src 'self' 'wasm-unsafe-eval'` | Only in an app carrying [patterns/wasm-client.md](patterns/wasm-client.md). Without it no browser compiles the module; `'unsafe-eval'` would also work and would also allow `eval`, so it stays banned. Its socket needs nothing: `wss:` (or `ws:` on a plain-HTTP dev page) to the page's own host and port falls under `default-src 'self'`. game and game-lab shipped this token as a conformance note against the gap before it was here. |
| Uploaded files | nothing | A file is served by the app's own handler, so `img-src 'self'` already covers a picture ([patterns/go-file-uploads.md](patterns/go-file-uploads.md)). What keeps that safe is not the policy but three rules in that document: the type comes from sniffing the bytes, `nosniff` makes it binding, and no link to the file is boosted, because htmx parses a boosted answer as HTML whatever its type and ignores both of the other two. A project that ever serves user files from a second origin needs a row here and a directive to match. |

Why each absent header stays absent:

- **`X-Frame-Options`** — superseded by `frame-ancestors`, honored by every browser in
  the support window. Two headers saying one thing is one more to keep in sync.
- **`Permissions-Policy`** — it mostly governs browser APIs a script calls; the rest
  (autoplay, a frame's `allow`) the app does not use. The only script that reaches the
  others is the app's own (htmx, or a WebAssembly client's module and loader), so a
  policy would restrict only the app against itself; the CSP refuses an injected one.
- **`object-src 'none'`** — `default-src 'self'` already denies cross-origin plugin
  content, and the app embeds none.
- **CSP reporting (`report-to`)** — needs an endpoint and somebody to read it. Add it
  when a real policy question needs real data.

## Waived budgets

Every size budget this repository is deliberately over, and what pays it back.
[README.md](README.md) *Size budgets* makes a budget a shape rule, waivable on the record
like any other, with the record kept here because the cost lands on this repository rather
than on a project built from it. Each entry carries the six fields a waiver carries
anywhere: the rule, the document, the date, who decided, why, and what contains it.

**Nothing waived.** The one entry that stood here — the checklist and change-path budgets,
first waived 2026-08-17 for the authorization section and re-measured 2026-08-17 when four
patterns landed — was closed on 2026-08-18 by moving the two numbers instead. The decision
is recorded under *Budget decisions* below, along with the rule that governs the next one.

**`make tokens` stays red while an entry sits here, and that is the point.** The red run is
the reminder, exactly as a `Last verified:` date past ninety days is the reminder. The way
to clear it is the work under *Paid back by*, or a deliberate move of the number in a commit
that moves nothing else — never an edit folded into the change that blew the budget, which
turns a waiver into a new normal with nobody deciding to.

**A waiver's numbers are measured last, or they describe a repository that no longer
exists.** The closed entry's first draft said 4,420 and 197; two fix passes later both were
wrong, and the same entry went stale a second time mid-run. Measure after the last fix of
the run, never carry a number over from the first draft.

## Budget decisions

Why a budget number is the number it is. A number here moves only in a commit that moves
nothing else — [README.md](README.md) *Size budgets* carries that rule; this is where the
argument behind each move lives.

### 2026-10-31 — the shape budget: a capped head, capped sections, a reported total

**Decided by Andy.** The checklist budget (5,000) and the change path (8,000) are gone.
In their place: **each checklist trigger section stays within 600 tokens**, and **the
head stays within 4,500** — `SKILL.md`, `VERSIONS.md`, and the checklist up to the end of
its *Every …* section. A checklist's total is reported. The per-document budget (3,800)
and the floor (25,000) did not move.

**The collision.** The entry below named its own end: both numbers going over together is
the growth curve arriving, and the signal to take the branch it did not take rather than
raise a third time. On 2026-10-31 the web-application checklist stood at 4,998 of 5,000
and its change path at 7,988 of 8,000, and seven baseline deviations that recur across
projects were waiting to be promoted, two of them on that path: a WebAssembly client, and
the boxes for a `/healthz` with no database to ping.

**Why this branch.** It is the one the 2026-08-18 entry deferred, and it dissolves the
collision instead of moving it. A new pattern adds a trigger section, and a trigger section
lands in neither capped number: it is capped on its own, and the head does not grow.
Measured at the switch: heads 3,852 (cli-tool), 3,711 (library), 3,744
(web-application); the largest section 499, the child-process section in
`checklists/cli-tool.md`.

**What it does not buy.** An agent that reads a checklist reads the file, not the sections
it fired, so the reported total is still what a change often pays in practice. The floor
is what still bounds it: every checklist sits inside its floor whole, and the floor has not
moved. **What would make this wrong:** a web-application floor that climbs toward 25,000
on trigger sections — then the checklist itself needs splitting, and no number fixes that.

### 2026-08-18 — the floor, raised so the corpus can keep growing

**Decided by Andy.** The floor 19,500 → **25,000**. The per-document budget (3,800), the
checklist (5,000), and the change path (8,000) did not move.

**The collision.** The entry below closed with the floor at 19,499 of 19,500 and said the
quiet part out loud: *the floor is the number that hurts, and it is the last one that
should ever move*. Thirteen tokens is not headroom, it is a stop, and the next rule proved
it. Building a voice assistant turned up a shape the corpus had no document for — work a
request starts and does not wait for, where `srv.Shutdown` waits for in-flight requests and
silently drops the goroutine that outlived one. It landed in
[patterns/go-background-work.md](patterns/go-background-work.md), which had 3,218 tokens
spare and needed no new file. Its trigger section did not: widening the schedule section in
`checklists/web-application.md` cost 61 tokens, the checklist absorbed it fine at 4,749 of
5,000, and the floor went 48 over — because the checklist sits inside the floor. The rule
that was meant to pay for it, move a document off *Required reading*, had nothing to move.
All seven of them change a decision made before the first line of code, which is the test
that list applies.

**Why raising was the right branch.** Three alternatives, each worse. *Trim 192 bytes from
the floor path* pays for one rule by cutting prose already at the bar *Write to the reader's
competence* sets, and buys nothing for the rule after it. *Ship the document with no trigger
section* is the failure [README.md](README.md) names outright — a document no box ever
checks is how a rule goes missing, and it is why routing and the definition of done became
one file. *Hold 19,500 and stop adding rules to the web-application path* caps the corpus's
growth on purpose, which is the one thing this repository exists not to do.

**What the number buys, and what it does not.** 5,452 tokens of headroom, against a floor
that grows about 125 tokens per new trigger section — roughly forty more before this
returns. The overshoot is deliberate: 19,700 would have cleared today's red and been full
again by the next rule, which is how a gate gets retired by making it normal to ignore.
What it does not buy is a cheaper read. An agent may now pay 25,000 tokens before its first
line of code, and whether it should is a judgement this budget no longer makes for anybody.
The two rules that kept the floor small still stand and are now the whole defence:
*Required reading* takes a document only if it changes a decision made before the first
line of code, and everything else is a trigger section.

**What would make this number wrong.** If the floor climbs toward 25,000 on trigger
sections rather than on *Required reading*, the checklist-inside-the-floor coupling is the
defect and not the number — the fix is the branch the entry below deferred: budget the
shared head, cap each trigger section. If an agent's output gets worse or slower as the
floor grows, the floor is too high whatever `make tokens` says, and the reach report is
where to look — rank by size times how often a document is read, and move the heaviest
*Required reading* entry to a trigger.

**A third path this entry missed.** `SKILL.md` and `VERSIONS.md` sit inside the floor
*and* inside the change path, and neither has a per-document budget: `make tokens` caps
`patterns/`, `stack/`, and `checklists/` and nothing else. The *Required reading* test does
not govern them either — they are the head every path starts from, not entries on a list.
`ebfc5e7` added *Handing the work back* to `SKILL.md` and spent 265 of this headroom, 5% of
it, one commit after the number moved. A per-document cap on the head is the branch not
taken: two documents do not need a gate, and the floor already bounds them together.
Naming it is the fix — growth in the head is a judgement, and it now has to be made out
loud.

### 2026-08-18 — the checklist and change-path numbers, raised once

**Decided by Andy.** `checklists/*.md` 4,300 → **5,000**, and the change path 7,000 →
**8,000**. The per-document budget (3,800) and the floor (19,500) did not move.

**The collision.** [README.md](README.md) *Maintenance protocol* promises that every
recurring decision becomes a pattern, and *Writing a checklist* will not let a pattern ship
without a trigger section — so each pattern costs the change path about 125 tokens, forever.
A fixed change budget and that promise cannot both hold. v3.8.0 waived the two budgets for
the authorization section; v3.9.0's four patterns re-measured them at 4,509 and 7,237 and
found the waiver had no way to close. A 509-token trim had already taken the prose to the
bar *Write to the reader's competence* sets, and what was left was boxes and one-line
section leads, where cutting deletes checks rather than words.

**Why raising was the right branch.** Three alternatives, each worse. *Budget the shape,
report the total* — a cap on the shared head and a cap per trigger section, the way reach is
already handled — dissolves the collision permanently, but leaves the most-paid path in the
corpus with no ceiling at all. *Hold 4,300 and make a new section pay for itself by retiring
an old one* caps the corpus's growth on purpose, which is the one thing this repository
exists not to do. *Leave the waiver standing* keeps `make tokens` red indefinitely, which
retires the gate by making it normal to ignore.

**What the numbers buy, and what they do not.** 491 tokens of checklist headroom and 763 of
change-path headroom: about six more patterns at the measured 125 apiece. This branch defers
the collision rather than dissolving it, and after those six it returns. That is the honest
cost, and it was chosen with it: four patterns in one release is not yet a growth curve, and
the shape budget is a bigger change to make on one release's evidence.

**The floor did not move, and it has one token of headroom.** 19,499 of 19,500 — and the
checklist sits inside the floor, so the next trigger section blows it by about 125 even
though the checklist itself now has room. That is not an oversight in this decision; it is
the floor's existing rule doing its job. Anything added to what an agent pays before its
first line of code gets paid for out of the same path, and the next pattern to land here
pays about 125 tokens somewhere among the seven required documents. The floor is the number
that hurts, and it is the last one that should ever move.

**What would make these numbers wrong.** If the change path passes 8,000 while the checklist
is still under 5,000, the shared head or `SKILL.md` grew rather than the corpus — trim, do
not raise. Both going over together is the growth curve arriving, and that is the signal to
take the branch not taken above rather than to raise a third time.

**Since then, and the head took nearly half of it.** The 763 is spent: **7,939 of 8,000**
on 2026-08-25, 61 left. [checklists/web-application.md](checklists/web-application.md)
took 486 of it, `SKILL.md` 380, and `VERSIONS.md` gave 165 back when v4.0.0 dropped the CI
rows — 701, against the 702 the path itself grew, because `make tokens` divides the whole
path's bytes once and not each file's. Only 179 of the 486 was a new pattern —
[patterns/go-data-deletion.md](patterns/go-data-deletion.md) in `9c0be4a`, the one of the
six the headroom was raised to buy that actually landed. The other 307 is catch-up and
boxes: sections at v3.11.0 for two patterns that had landed a release earlier — background
work, and the streaming rules — and the `make ci` boxes at v4.0.0, which have no pattern
behind them at all. Against the sections measured — 61 for background work in `34ab524`,
179 here, 201 for authorization in `64babfb` — the 125 this entry budgets by is an average
nobody pays, not a rate.

**The head took 380 of it, which is *A third path this entry missed* firing.** Both edits
landed in `SKILL.md`, which no per-document budget caps and no *Required reading* test
governs: *Handing the work back* at 266 — 265 as that paragraph counted it, the same
rounding — and the gap bullet at 116. The floor pays for both too — 19,973 → 20,089 of
25,000. The judgement that paragraph asked to be made out loud, made: the bullet is worth
116 because a gap nobody writes down is a gap found again by the next project, and it is
the last thing this path can carry. *What would make these numbers wrong* names this cause
exactly, and its threshold has not been crossed — 7,939 is under 8,000 — so the reading is
*trim, do not raise*. Which trim, or the shape budget instead, is a decision rather than a
measurement, and the next pattern waits on it: 61 tokens buys no trigger section, least of
all a 179-token one.

**Settled since.** v4.3.0 took the trim branch; v4.6.0 left the path at 8,000 of 8,000;
v4.7.0 left it at 7,985, and v4.8.0 at 7,963. The next pattern on the web-application
path still needs a budget decision first.

## Where the numbers come from

`VERSIONS.md` carries its own dated source list. Re-verify against those links,
never against memory or training data — and never against a search result that
does not name a version.
