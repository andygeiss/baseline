# Verification Record

**Last verified: 2026-08-25**

How this repository proves it is right, and what every review run found. The
README states the standard in a paragraph; this file holds the evidence and the
history behind it. It is written for whoever is about to tag a release, or is
auditing whether a rule was ever actually checked.

## What a review run is

A run has two halves, and a release needs both.

1. **The adversarial half.** Independent reviewers hunt cross-document
   contradictions, trace every canonical snippet's mechanics end to end, and
   check factual claims against upstream sources (Go, htmx, scs, SQLite). They
   repeat until **two consecutive passes find zero defects**. Reading is not
   enough on its own: every canonical Go snippet gets compiled and run through
   `gofmt`, `go vet`, `go fix -diff`, `staticcheck`, and `govulncheck`, the
   canonical `Makefile` runs end to end under GNU Make 3.81, the version macOS's
   Command Line Tools ship, and every measured color claim gets recomputed from its
   oklch values.
2. **The empirical half.** [baseline-reference](https://github.com/andygeiss/baseline-reference)
   implements the corpus end to end. It is synced to the change, and its
   `./verify.sh` runs every mechanical gate, then boots the real binary and
   smoke-tests the running application. This is the only half that catches rules
   that are each correct and do not compose.

The two halves catch different bugs. Document review found the stale
`X-Forwarded-For` fact below; only a running application would have found a rule
that contradicts another one nothing points at.

## The tag gate

**No tag ships until all five are true.** This is a gate, not a goal.

1. Two consecutive adversarial passes over the changed documents find zero defects.
2. The reference implementation is synced to the change, and `./verify.sh` exits
   0 against the baseline commit its `SPEC.md` pins.
3. The reference's `SPEC.md` pins that commit, and its own tag mirrors the
   baseline version.
4. **Nothing a project reads changed between the pinned commit and the tag.**
   `git diff --name-only <pin> <tag>` names this file and nothing else.
5. The run is recorded below, naming the reference commit and the `verify.sh`
   result.

**Conditions 2 and 4 were one sentence until 2026-08-18, and it was one no release
could meet.** It read "`./verify.sh` exits 0 against the exact baseline commit
being tagged" — but condition 5 names the reference commit, so the record cannot
be written until the reference is synced and tagged, and the reference cannot pin
a commit that does not exist yet. The order is forced: the rules commit, the
reference synced and tagged against it, the record, then the tag on the record.
A reference pinning the tagged commit would be pinning a commit that names it.

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

## Owed: changes not yet through a run

**`go fix` joins the gates.** `go fix -diff ./...` is the third line of `check` and
`go fix ./...` the last of `fmt` ([stack/makefile.md](stack/makefile.md),
[operations/ci.md](operations/ci.md), [stack/go.md](stack/go.md)), and three fences are
rewritten: the one the pinned toolchain rewrites (`go-background-work.md`) and the two
the next major will — `errorsastype` is Go 1.27's (`go-file-uploads.md`,
`go-forms-validation.md`). In [stack/go.md](stack/go.md) the `any` rule is gone — the
pin's `any` fixer enforces it — and `errors.AsType` joins the errors row. A moved Go pin
now means `make fmt` first, as its own commit ([README.md](README.md) *Maintenance
protocol*, [operations/ci.md](operations/ci.md) *Dependency updates*; its *The Go
version* says why a newer major goes red). The run is owed; the tag waits on it.

## Run log

Newest first.

### 2026-08-25 — gaps flow back from projects (v4.1.0)

**The corpus could learn from projects and had no way to hear about it.** Every rule here
was written by looking at the corpus. The two things only a project can show — a decision
the checklist has no section for, and a rule naming a dependency the standard library has
since absorbed — were visible exactly once, to whoever hit them, and died with the task.
`SKILL.md` *Handing the work back* now takes the first as a next step and `README.md`
*Maintenance protocol* takes the second at every Go major, where the release notes get
read for what moved into stdlib and not only for what changed.

**The rule's failure mode is noise, not silence, so the bar is the whole design.** A
reflect-on-your-work rule with a soft trigger fires on every task and is skimmed past by
the third one. Two kinds qualify and the bullet says so: the checklist had no section and
you settled it by inventing rather than by matching the surrounding code, or a baseline
rule names a dependency stdlib now covers. Both are facts the agent already holds when it
finishes; neither needs a survey. "This looked reusable" is named and excluded. It was
tested by looking for a gap rather than by reading the rule: inbound webhooks — the HMAC,
the replay window, the raw body read before parsing — are genuinely uncovered by this
corpus, and CSV downloads look uncovered and are not — they are boxes under *Taking a
file from a user*. The false guess is the point of the bar.

**Absorption is a rewrite, not a retirement, and that had to be said where retirement is
decided.** A pattern whose dependency moves into the standard library still has something
to say — the mechanism changes and the document stays. Only a pattern that existed solely
to cover the gap meets signal 1. Without that paragraph, *Retiring a pattern* reads as a
licence to delete a document the day Go absorbs its dependency, which is the moment its
rules are most likely to be got wrong.

**Nine defects over ten passes, the last two clean, and two more in this entry as it was
written; the interesting ones were arithmetic.** They were sequential rather than
independent again: one reviewer, each pass on a different surface — cross-document section
names, then the budget numbers re-derived from `git show` rather than read, then the rules
tested against a real gap and a real false gap, then margins and the corpus's own `make
structure` and `make tokens`, then the whole diff. The first draft of this release's
budget paragraph said the six patterns the 2026-08-18 raise bought had never landed. One
had: `9c0be4a`, *Deleting a person*, on the same day the number moved. The same paragraph
called the 125-tokens-per-pattern figure a rate; the sections measured since cost 61, 179,
and 201, so it is an average nobody pays. A third claim was off by one token, because
`make tokens` divides the whole path's bytes once and the per-file deltas each round down.
The two caught in this entry are the same kind: a 380 said to have accrued since a
paragraph that reports 265 of it itself, and that 265, which today's per-file measure
makes 266. Every one of them came from re-deriving a number that had been carried over
from a draft — the failure *Waived budgets* already names.

**A judgement the entry above demanded, made out loud.** *A third path this entry missed*
recorded on 2026-08-18 that `SKILL.md` and `VERSIONS.md` sit inside both the floor and the
change path with no per-document budget over either, and asked that growth there be argued
rather than absorbed. This release grew `SKILL.md` by 116, the second such edit and 380 in
total since the raise — nearly half the 763 it bought — and the argument is in *Budget
decisions* below with the full accounting. The change path is at **7,939 of 8,000**, 61
left, which buys no trigger section; the floor at 20,089 of 25,000. What the next pattern
costs is now a decision Andy makes before it lands, and *What would make these numbers
wrong* already names the branch: trim, do not raise.

**One defect was found and not fixed.** The new bullet ends "nothing else qualifies", and
`SKILL.md` *Waivers and conflicts* separately tells an agent that an unresolvable rule
collision is a defect in the baseline, to be told to the user at the moment it happens. A
reader could take the first sentence to scope out the second. It was left alone: the two
have different mechanisms and different timing — the collision is reported when it blocks
you, the gap when you hand the work back — and the clause that would join them costs about
15 of the 61 tokens left on the corpus's most-paid path. Spending the last of a budget to
pre-empt a misreading, in the same release that says the budget is spent, is the wrong
trade. It is written down here instead, which is what this file is for.

**Two runs compressed on the way out.** v3.11.0 and v3.10.0 moved into *Earlier runs*,
which is [README.md](README.md)'s three-newest rule doing its job rather than a decision
this release made: with this entry the log had five in full. What a future reader would
otherwise re-derive stayed — the counts, the reference commits, and the findings that cost
a pass to reach.

**The empirical half:**
[baseline-reference](https://github.com/andygeiss/baseline-reference) `6239e4e`, tagged
v4.1.0, pinning baseline `99a94e0`. `SPEC.md` is the only file that moved there, and that
is the finding: both rules govern what an agent reports and what a maintainer does on the
90-day cycle, so neither is a property a repository can gate. `GOTOOLCHAIN=go1.26.7
./verify.sh` exits 0 over **76 gates**, the same count as v4.0.0 since no gate moved, and
`GOTOOLCHAIN=go1.26.7 make ci` is green on `6239e4e` with `go version go1.26.7
darwin/arm64` as its first line. The toolchain pin still stands in for this machine's Go
1.27.0, which the policy does not adopt until 1.27.1. A rules change the reference cannot
gate is exactly the kind that gets tagged on a reading, so it was run rather than reasoned
about.

### 2026-08-25 — the CI server dropped (v4.0.0)

**A second machine was doing the first machine's work.** The runner bought a run on a
clean checkout, a weekly `govulncheck` over untouched code, and a per-gate red/green
view; it cost a hosting vendor, a YAML dialect, an action-major deprecation cycle
carried in [VERSIONS.md](VERSIONS.md), and a bot opening pull requests only the pusher
read. `make ci` buys the first back — `git archive HEAD` into an empty directory, then
the same `check`, so nothing missing from `git add` and no `.env` can make it green.
The other two moved to a person, and [operations/ci.md](operations/ci.md) now names
who: the toolchain is whichever Go the machine resolves, and the scan of code nobody
touched runs on the 90-day cycle with the pins.

**The `ci` recipe was wrong twice before it was right, and only running it said so.**
The first form piped `git archive` into `tar`, so the shell reported the pipe's last
status and a failed archive still ran the gates against an empty directory — reproduced
in a repository with no `HEAD`, where the piped form exits 0 and the file form exits
128. The second put `go version` on its own recipe line, outside the copy, where
`GOTOOLCHAIN` resolves against the *working tree's* `go.mod` rather than the archived
one; `go -C "$d" version` inside the copy reports the toolchain `check` will actually
use. Both forms read correctly. Neither survived being run.

**Four claims about the go command were settled by executing them, not by reading the
documentation.** Under `GOTOOLCHAIN=go1.26.7`, `go get` against a `go.mod` that says
`go 1.27` refuses with `go.mod requires go >= 1.27 (running go 1.26.7;
GOTOOLCHAIN=go1.26.7)` and leaves the file alone; under `auto` the same command prints
one line, `go: upgraded go 1.26 => 1.27`, and raises it; `go mod tidy` raises it with
**no output at all**, which is why the document tells you to look; and `go mod edit`
works either way, because it never reads the module graph. A module cache's directories
really are read-only, so the release check's `rm -rf` fails with *Permission denied* and
`go clean -modcache` is the line that works.

**The defect class this release names is the absent file.** No passing suite notices a
workflow that should not be there, so the reference gates it instead: nothing under
`.github/workflows/`, no `dependabot.yml`, and no `export-ignore` in `.gitattributes` —
the last because `git archive` honours that attribute and the go command does not, so a
marked file makes `make ci` green against a tree `go install` never builds. A second new
gate reads the Makefile itself: targets alphabetical, `check` named as `.DEFAULT_GOAL`.
Both are cheap, and both check something ten readings had not.

**The budget went red, and was paid rather than moved.** The new boxes pushed
[checklists/web-application.md](checklists/web-application.md) to 5,008 against its
5,000 — 8 tokens over. `make tokens` said so on the first run after the change, before
any of it was tagged. It was paid by taking the web checklist's Makefile box back to the
CLI checklist's exact wording and by dropping one clause the section already said twice
("nothing runs it for you", on the `make ci` box and again on the `GOOS` box). 4,995
now, and no number moved.

**Eleven defects in the closing rounds, the last two clean, and the record should say
what the passes were.** They were sequential rather than independent: one reviewer,
several passes, each checking a different surface — cross-document references and
section names, then the go-command claims by execution, then every changed document's
margin and the corpus's own `make structure` and `make tokens` gates, then the reference
against each new box. Two of the eleven came from the earlier rules commit rather than
this one, both prose pushed past the margin in
[patterns/go-ports-adapters.md](patterns/go-ports-adapters.md). The repository's own
`Makefile` was one too: `c3d2438` made its targets alphabetical and cited
[stack/makefile.md](stack/makefile.md) rule 3 for it, while leaving the second half of
that rule — name the default — unadopted. It has `.DEFAULT_GOAL = install` now. A
repository that exempts its own tooling from the rule it just tightened is the cheapest
kind of wrong to be.

**The empirical half:** [baseline-reference](https://github.com/andygeiss/baseline-reference)
`9edcd6a`, tagged v4.0.0, pinning baseline `7703305`. `GOTOOLCHAIN=go1.26.7 ./verify.sh`
exits 0 over **76 gates**, two of them the new ones above;
`GOTOOLCHAIN=go1.26.7 make ci` is green on that commit and its first line reads
`go version go1.26.7 darwin/arm64` — the toolchain pin still stands in for the machine's
own Go 1.27.0, which the policy does not adopt until 1.27.1. The reference's module path
moved `/v3` → `/v4` in `go.mod` and every import, because a v4 tag on a `/v3` module
never stamps.

### 2026-08-25 — the pins, checked against their sources (v3.11.1)

**One row moved, and the others were checked rather than assumed.** Every numbered row in
[VERSIONS.md](VERSIONS.md) was read against the source its own list names, on the day; the
rolling rows (CSS Baseline, HTML, Make) have no number to move and were confirmed only as
still reachable. That is what the table's new date means — not only the row that changed.

**Go moved twice on one day, and the policy answers both.** Go 1.26.7 and Go 1.27.0 both
shipped on 2026-08-19. The pin is now **1.26.7**: *always run the latest patch release*.
1.27.0 is not adopted: *adopt a new major after its first patch release*, so 1.27.1 is the
trigger, and the table says so. The patch is a point release rather than a security one —
it restores unencrypted HTTP/2 after 1.26.6's `net/http` fix left `ReadHeaderTimeout` armed
across the h2c handoff (go.dev/issue/80876). Checked rather than assumed: nothing in this
corpus, the reference, or `baseline-ops` enables h2c, and nothing configures Caddy to speak
it toward an application — so the regression could not reach a conforming app, and 1.26.6's
advisories remain the reason the line has a floor at all.

**What did not move, and where it was checked.** htmx 2.0.10 is still the newest 2.x on
npm and 4.0.0-beta6 the newest tag; scs v2.9.0 is the newest tag; `actions/checkout` is at
v7.0.1 and `actions/setup-go` at v7.0.0, both `using: node24` in `action.yml` on the `v7`
tag; `design.md` still says `alpha` in its README's *Status* section while the CLI's newest
tag is 0.4.0 — the two numbers the table's source note warns not to confuse.

**Nothing downstream needed an edit, and that was checked too.** The reference's `go.mod`
says `go 1.26` with no toolchain line, its CI resolves the version from `go.mod`, and the
`baseline-ops` Dockerfile builds `FROM golang:1.26-alpine` — a floating minor tag, which its
README already records as deliberate. All three pick up 1.26.7 without a commit. The one
place that does not is this machine: Homebrew's Go is now 1.27.0, so a bare `./verify.sh`
here builds with the major the policy has not adopted, and the `govulncheck` binary here,
built with 1.26, refuses 1.27's standard library outright. **The run below was pinned with
`GOTOOLCHAIN=go1.26.7`**, and until 1.27.1 lands so should any local run.

**The empirical half:** [baseline-reference](https://github.com/andygeiss/baseline-reference)
`bb315d5`, tagged v3.11.1, pinning baseline `b342f17` — `SPEC.md` is the only file that moved
there. `GOTOOLCHAIN=go1.26.7 ./verify.sh` exits 0 over 74 gates, run once against `b3cdc7a`
before the pin moved and once after.
`govulncheck` under the same toolchain: 0 vulnerabilities called, 0 in imported packages,
one in a required module — GO-2026-5932, `golang.org/x/crypto/openpgp` "unsafe by design",
never imported here and with no fixed version — informational.

**What 1.27.1 will ask, written down now so the adoption pass does not start from the
release notes.** `httptest.NewTestServer` gives a `synctest` bubble an in-memory network,
which bears directly on the listener-outside-the-bubble constraint in
[go-background-work.md](patterns/go-background-work.md); `synctest.Sleep` folds `time.Sleep`
and `Wait` into one call; `Server.MaxHeaderValueCount` is a new limit
[go-http-server.md](patterns/go-http-server.md) will have to rule on; `go test` runs the
`stdversion` vet check by default; `go mod tidy` merges `require` blocks once `go.mod` says
`go 1.27`; and `encoding/json/v2` arrives, rejecting duplicate names and invalid UTF-8 by
default.

**No document stamp moved except the pin line.** [stack/go.md](stack/go.md) names the pinned
version on its stamp line and now says 1.26.7; its *Last verified* date did not move, the
same shape as the 1.26.6 bump. **Tagged v3.11.1** on the commit that records this run, one
past the pin `b342f17` — the shape every release since v3.6.0 has had, and condition 4
holds by construction: the diff between them is this file.

### Earlier runs

Compressed to what a future reader still needs: the counts, and the findings that would
otherwise be re-litigated. The full narratives are in this file's git history.

**The three newest runs stay in full; everything older lives here.** A run log that only
grows costs more to re-read than it saves, and the compression is what keeps a narrative
from being re-litigated a year after it was settled.

- **2026-08-18 — the six changes that were owed (v3.11.0).** 47 defects over ten
  adversarial passes and one empirical pass, the last two clean. **The headline was a rule
  right on its own and wrong in a container:** detached work told `main` to wait on a
  budget measured in minutes, inside a 15 s `stop_grace_period`, so SIGKILL dropped it
  mid-write with nothing logged — the exact failure the wait was added to prevent. The fix
  is `context.AfterFunc` hanging each job's cancel off the errgroup's context, which is
  cancelled *as* `Wait` returns (checked in x/sync's `errgroup.go`, not remembered). The
  same change had no boundary; the first fix drew it at duration, *seconds not minutes*,
  and a later pass killed that — **the axis is whether losing the work is survivable**,
  since a streamed reply runs for a minute and still belongs there. A checklist and the
  document it routes to disagreed twice in opposite directions — one rule moved without
  its box, one box without its rule, and neither `make structure` nor `make tokens` can
  see it. A canonical snippet was its own document's anti-pattern (`hx-trigger="every
  1s"`, forbidden by that exact string), which scoped the anti-pattern to lists rather
  than fixing the snippet; "no bare `go func()` anywhere" became "in a server", because
  [go-cli.md](patterns/go-cli.md) had recommended one for releases; and `bufio.Scanner`
  caps a line at 64 KiB reporting `ErrTooLong` only through `Err()`, so the SSE reader
  rule ended a long answer early and silently. **Where the defects came from:** 16 from
  reading the changes, 30 from re-reading the fixes, 1 from building them — a fix is a
  change and earns the same passes. **The empirical half refuted a rule this file had
  accepted:** *tests wait on the counter* is half an answer, since deleting
  `a.running.Add(1)` left every test green — an uncounted goroutine still finishes first
  on an idle machine. `testing/synctest` is the real answer, red in 0.04 s with no clock,
  and it brought two constraints only running it produces: a listener stays outside the
  bubble, and so does anything holding a ticker that never exits (`scs`'s in-memory store
  does). Reference `b3cdc7a` tagged v3.11.0, pinning `b94cbeb`, `./verify.sh` exit 0 over
  74 gates, three new — and **every new assertion was proved to fail first.**

- **2026-08-18 — the document for data leaving (v3.10.0).** 18 defects over eleven passes,
  the last two clean; 3 came from building the rules, and only those caught rules that
  were *wrong* rather than badly worded. Every document ruled data arriving and nothing
  ruled a person leaving — [go-data-deletion.md](patterns/go-data-deletion.md) is tier 1
  and closes it. **Three rules did not survive contact with the reference.** The headline
  all-tables sweep reads `sqlite_master` at runtime and finds the deleted id in every text
  column — so it matches rows naming the person *by id*, while the outbox held an address
  and no `user_id`, and stayed green with the address on disk; the rule now says the sweep
  finds references, not copies, and asks for a by-value assertion beside it. SQLite cannot
  alter a constraint, so changing an `ON DELETE` action is create-copy-drop-rename, and
  `DROP TABLE` with foreign keys on fires an implicit `DELETE FROM` that takes the
  children — with the usual escape closed inside one transaction, where `PRAGMA
  foreign_keys` is a no-op; that is why the reference keeps **erase** rather than
  **anonymize**, an answer free before the table ships and expensive after. And an
  anti-pattern was too wide: banning "a confirmation that is a JavaScript dialog" would
  have banned the `hx-confirm` the reference already uses, so the rule now says an
  irreversible action asks for something the *server* can check. **One rule the reference
  had already met:** `authenticate` loaded the user row and destroyed the session when it
  was gone, written long before this document asserted it — sessions are the hole no
  cascade reaches, because the row is keyed by token and opaque to SQL. **The defect class
  the last passes kept finding was a stale claim elsewhere:** deletability made
  [glossary.md](patterns/glossary.md)'s example and the reference's *Who owns what* row
  false where they said a message is never deleted — a new capability falsifies prose in
  documents it never touches, and only a grep for the contradicted claim finds it. A
  by-value checklist box was deliberately not added, at thirteen tokens of floor headroom
  against about twenty, and recorded rather than quietly dropped. The budget raise to
  5,000 and 8,000 came first and alone, in a commit that moved nothing else. Reference
  `dadfb2f` tagged v3.10.0, pinning `c1ca89f`, `./verify.sh` exit 0.

- **2026-08-17 — four patterns, and the passes that rewrote them (v3.9.0).** 44 defects over
  12 passes, the last two clean; every one of the four new documents was wrong about
  something it stated confidently. **The worst was a contradiction neither document could
  see alone:** [htmx-lists.md](patterns/htmx-lists.md) made the last row a control and
  [htmx-live-updates.md](patterns/htmx-live-updates.md) had made it the poller for three
  releases, so a chat paging backwards loses one mechanism — the rule is now *the far end
  from where new rows arrive*, both directions spelled out. Three more of that shape:
  `go-email.md` put the port and its fake in `domain` against
  [go-ports-adapters.md](patterns/go-ports-adapters.md); "a handler that names the actor"
  stood in three places and the reference could not satisfy it for an attachment in a shared
  room, so it is "a handler rather than a file server" and the actor returns on delete; and
  [security-headers.md](patterns/security-headers.md) had pointed since v1.14.0 at an uploads
  document that did not exist. `time-and-dates.md` rule 1 was right for the wrong reason — a
  `time.Parse`d RFC 3339 value renders the same everywhere; `time.Unix` is the one that goes
  local. `EXPLAIN QUERY PLAN` on SQLite 3.54 refuted "the index matches the order exactly":
  an ASC index serves a DESC keyset scan without a temp b-tree. Nothing in
  [patterns/](patterns/) pointed at the four new documents; four back-links fixed it, one
  broke the floor, and it was trimmed rather than waived — 19,499 of 19,500, change path
  7,237. Reference `cbba3c2` tagged v3.9.0, pinning `12dc414`, `./verify.sh` exit 0 with
  eight new gates. **The question it left: how do you delete a person** — every document in
  the release was about data arriving.

- **2026-08-17 — the rule that was missing (v3.8.0).** 20 defects over 11 passes, the last
  two clean; 2 came from the empirical half and refuted rules this file had already accepted.
  [go-auth-sessions.md](patterns/go-auth-sessions.md) answered *who is signed in*; **nothing
  answered *may this actor touch this row***, and a handler rendering somebody else's row
  passed every box in every checklist. The gap was found by asking what no document said, so
  **a pass now ends by naming the question the corpus cannot answer.** The reference refuted
  the first draft twice: private-by-default had mandated a mechanism (a mux behind
  `requireLogin`) that loses the collection path when routes do not nest — `GET /rooms`
  redirecting to `/rooms/` and then 404ing, verified on Go 1.26.6 — so the rule now states
  the invariant, **a route's protection MUST NOT be optional where it is registered**; and
  "404 for somebody else's row" cannot be met by a mutation that redirects, so the rule is
  that **the two answers match** and the status follows the route — never 403, because a 403
  confirms the row exists. The release opened on two shape defects twelve earlier passes had
  read past — a README tree out of order and a tier-3 stamp missing four words — and
  `make structure` exists because **a claim of mechanical checkability that nothing
  mechanically checks is a claim that decays**; it is an input to the adversarial half, not a
  fifth condition. Pass 8 found the reference pinned to a commit seven fix passes had
  superseded: **a pin is the one field the protocol cannot check by reading the file it sits
  in.** The floor closed at 19,498 of 19,500 by tightening a pointer and deleting a
  `SameSite=Lax` duplicate rather than waiving — the finding the release left for the next
  one. Reference `ba60701` tagged v3.8.0, pinning `5538323`, `./verify.sh` exit 0 over 61
  gates; every new check was verified by breaking the thing it checks.

- **2026-08-17 — the router folded into the checklist (v3.7.0).** 7 defects over 12 passes,
  the last two clean; 2 of the 7 were introduced by the run's own fixes. An ordinary change
  to a conforming web application fell 8,091 → 6,980 tokens, floor + checklist 20,287 →
  19,182, reach 87,445 → 80,822. **The router and the checklist were the same rows with
  different payloads** — one said *read this*, the other *this is what done looks like* — so
  they became one file per project type, one section per topic. **That fusion made a defect
  class unrepresentable:** a row pointing at a document no box checks cannot be written any
  more, because the row *is* the box's heading. Wiring the CLI checklist caught one on the
  way in — its router had named [patterns/go-sqlite.md](patterns/go-sqlite.md) since it
  existed and no box had ever checked it. **Write to the reader's competence** entered
  [README.md](README.md) *Size budgets* here, and the test is one question: would a
  competent Go engineer get this wrong from the rule sentence alone?
  [patterns/go-http-client.md](patterns/go-http-client.md) fell 4,573 → 3,774 with its code
  half halved; [patterns/design-system.md](patterns/design-system.md) was held against the
  same test and left alone, because its `DESIGN.md` template *is* the payload.

- **2026-08-17 — what the corpus costs to read (v3.6.0).** 2 defects over 3 passes, the last
  two clean, and both were losses the sweep itself introduced — the risk of a prose rewrite.
  Required reading for a web application fell 29,855 → 18,252 tokens, the CLI 18,384 →
  9,801, the library 16,604 → 11,580. **"No rule was removed" was checked rather than
  asserted:** every RFC-2119 keyword counted before and after (129 both times), and the five
  files whose local count moved read line by line against their pre-sweep versions. Two were
  real losses, both restored — [patterns/go-config.md](patterns/go-config.md) rule 1's MUST
  NOT about a bad `PORT` reaching a half-started process that already created files, and
  [patterns/design-system.md](patterns/design-system.md)'s MAY for a Claude Design sync
  integration. **[SKILL.md](SKILL.md) became the whole agent protocol and
  [README.md](README.md) the maintainer's document**, because a protocol stated twice drifts
  in one copy; six documents left *Required reading* against one test — does this change a
  decision made before the first line of code? — and `security-headers` stayed despite a
  clean trigger, because it is tier 1. **Tier 1 became a test rather than a position**, after
  three secret-handling rules met every part of it from under *Code quality*. Size budgets
  were invented here; their numbers are superseded twice over, and *Budget decisions* below
  is the current answer.

- **2026-08-17 — a pattern nothing pointed at (v3.5.1).** 7 defects over 5 passes, the last
  two clean; six of the seven were in the fix rather than in the corpus, which is what a
  small change reviewed properly looks like. [patterns/local-https.md](patterns/local-https.md)
  had shipped inside v3.5.0 with no trigger row, no checklist box, and no line here — rules
  an agent would meet only by accident. **No rule changed**, which is why it was a patch: the
  corpus gained navigation and enforcement. Three findings survive. **A document nothing
  points at is unreachable, not optional** — the defect class the v3.7.0 router fusion later
  made unrepresentable. **The trust rule got its own box** because "the binary never serves
  TLS" and "a developer needs HTTPS on a phone" are only compatible through a proxy the
  binary cannot know about: proxied and direct response bodies were **byte-identical** under
  Caddy 2.11.4 against the real binary, which is the sharpest evidence of that. **Both numeric
  claims reproduced** a day after they were written — the served certificate valid 12 hours,
  the root 10 years. Empirical half closed before the tag: reference synced and tagged
  v3.5.1, `./verify.sh` exit 0 over 60 gates including the six new ones.

- **2026-08-17 — the LLM adapter, the timeout ladder, one box one check (v3.5.0).** 17
  defects over 12 passes; 3 of them introduced by the fixes and caught by the pass after,
  which is the argument for running the pass after the one that looks finished. Five
  findings survive. **`unknown` at `/healthz` now means the opposite thing** — the
  canonical `resolveVersion` never returns it, so `unknown` says the wrong reader is
  wired in, and the real symptom of a missing `.git` is a version that changes every
  restart. **The ladder and the retry policy disagreed silently:** a client timeout at or
  above the budget means `Timeout` never fires first, so retries cannot run inside a
  budgeted handler; the ladder states that trade rather than leaving both documents right
  alone and unresolvable together. **Undeclared identifiers were the run's most repeated
  defect**, three times in three documents — hence the standing check that every
  identifier a snippet uses is declared in that snippet or one the same document shows.
  **The tag carried a tenth change the entry never named** (`patterns/local-https.md`),
  because the audit held the list against itself and a change that never joined the list
  could not fail it — hence the standing check that `git diff --stat <last tag>..HEAD` is
  the list, not memory. The checklists also split their compound boxes (web 65 → 177,
  cli 33 → 75, library 23 → 44; only library's is the split alone), and README gained
  *Retiring a pattern*, shipped ahead of its first use so the first retirement would not
  also be the argument about how to do one.
- **2026-08-16 — the glossary pattern (v3.4.0).** 30 defects over 10 passes. A new
  document has to be held against itself, and four findings survive: what earns a word its
  place is **the project giving a general term a specific job**, not the project inventing
  it; the example's own *Label* collided with HTML's, and ships as *Token label*; a
  `git grep` check on *Avoid* words is concept-scoped, because `channel` hits every Go
  `chan`; and the pattern declares its own two [STYLE.md](STYLE.md) exceptions (no runnable
  first screen, cluster headings). Writing the reference's glossary added two more:
  *sender* is a role the live-update design needs, not an *Avoid* word, and entries are
  **alphabetical**. **Deliberately left alone:** `/register`, "Make an account", and
  `signUp` are the same act in three registers — not drift, because rule 2 scopes entries
  to nouns and UI copy phrases an action for people.
- **2026-08-15 — full re-review (v3.3.1).** 3 defects over 5 rounds, and two were this file
  being wrong about its own evidence. **The `Secure` cookie rule had only ever been fixed
  in the reference**, so the corpus disagreed with its own executable check for a release;
  it now lives in the baseline. **Both claims about what the flat flag breaks were
  overstated** — measured, `curl` stores and returns a `Secure` cookie over
  `http://localhost` and `http://127.0.0.1`, so loopback is fine and what actually fails is
  a phone, a container reached by hostname, and a plain-HTTP staging box. The rule stands;
  only its stated reason was wrong. **The `responseHandling` warning named a safe edit:**
  narrowing `[23]..` to `2..` does *not* break 286, because `2..` still matches it. The
  real dangerous edits are now a table in
  [patterns/htmx-live-updates.md](patterns/htmx-live-updates.md), including that grouping
  `422` after `[45]..` silently kills the whole form-validation flow. Also recorded:
  v3.3.0 was tagged with no entry here, breaking gate item 4 one release after it was
  introduced.
- **2026-08-15 — live updates, machine tokens, a second binary (v3.2.0).** 13 defects over
  8 passes, from replacing the reference application: the todo app had closed every rule it
  could reach, so **Go Chat** — a chat application with a CLI client — took over and gave
  `project-types/cli-tool.md` its first reference. Two older defects found by doing the work
  rather than reading it: **`go-ports-adapters.md` was missing from the README tree since
  v2.1.0 and had no checklist box in any checklist** — a pattern nothing enforced, which is
  exactly how the todo app kept every gate green with the adapter half unexercised. The
  two empirical findings of that run (the `Secure` cookie, htmx's 286) are both corrected
  by the v3.3.1 entry above; read that one, not the original wording.
- **2026-08-15 — governance: the gate, the tiers, the staleness switch (v3.1.0).** 1
  defect, found by the sync, which is the point: the waiver format first mandated the
  heading `## Waived baseline rules`, which would have relabelled the reference's "this app
  needs no backups" as a waived rule. **The six fields are the rule; the heading fits the
  list.** Applying it also showed what the format is for — five real waivers there had a
  rule, a reason, and containment, but **no date and no decider**.
- **2026-08-15 — the operations split (v3.0.0, stamp fixed in v3.0.1).** 16 defects across
  12 documents. The two that mattered: the split dropped the fact that `X-Forwarded-For`
  arrives holding **one address, not a chain**, with no `RemoteAddr` fallback, so every
  visitor keyed on `""`; and `VACUUM INTO` resolves against the **process's working
  directory**, not the database's. **The lesson, recorded because it will recur: an
  extraction drops facts its consumers still need — sweep every consumer after moving
  anything out.**
- **2026-08-15 — full-corpus sweep (v2.0.1).** 7 defects: a two-pool SQLite snippet that
  did not compile and dropped both error checks; a bottom-nav rule telling readers to delete
  a grid row the fixed bar never vacated; htmx's history cache named `sessionStorage` when
  it is `localStorage`; a `primary` palette called required by the `design.md` spec, which
  only warns; a `debug.ReadBuildInfo` one-liner discarding the `ok` it must check; two list
  recipes whose `list-style: none` strips list semantics in Safari; and a field error tied
  to its control for the eye only. **Empirical half: missing** — the reference was not
  re-synced in this run.
- **2026-08-14** — re-review of the v1.14.0 additions (security-headers, go-http-client,
  go-config). 4 defects. The one worth remembering: a retry that sends an empty body on the
  second attempt.
- **2026-08-13** — css-typography and css-icons. 7 rounds, 29 defects, converged.


## Why the CSP is what it is

The standing record behind [patterns/security-headers.md](patterns/security-headers.md).
That document owns the policy and every rule; this section owns the argument, so an agent
following the policy never pays for it and an agent changing the policy can check its
work. **Add a row here when the policy changes.**

Every feature in the baseline, and what it needs:

| Feature | Needs | Covered by |
|---|---|---|
| htmx | `script-src 'self'` | `default-src`; htmx is self-hosted, no inline JS ([stack/htmx.md](stack/htmx.md)). |
| htmx indicators | nothing | htmx would inject an inline `<style>`, which `default-src 'self'` blocks. The canonical layout sets `"includeIndicatorStyles":false` and `app.css` owns those rules ([stack/css.md](stack/css.md)). |
| Mask icons | `img-src data:` | The one directive a default policy would get wrong. |
| Self-hosted font | nothing | Same-origin `.woff2` ([patterns/css-typography.md](patterns/css-typography.md)). A third-party font host would need a `font-src` hole — one reason there isn't one. |
| Web app manifest | nothing | `manifest-src` falls back to `default-src`, and the manifest is same-origin ([patterns/pwa.md](patterns/pwa.md)). |
| View transitions, CSS motion | nothing | Pure CSS ([patterns/css-motion.md](patterns/css-motion.md)). |
| Forms | `form-action 'self'` | Already in the policy. |
| Uploaded pictures | nothing | An attachment is served by the app's own handler, so `img-src 'self'` already covers it ([patterns/go-file-uploads.md](patterns/go-file-uploads.md)). What keeps that safe is not the policy but the pair of rules in that document: the type comes from sniffing the bytes, and `nosniff` makes it binding. A project that ever serves user files from a second origin needs a row here and a directive to match. |

Why each absent header stays absent:

- **`X-Frame-Options`** — superseded by `frame-ancestors`, honored by every browser in
  the support window. Two headers saying one thing is one more to keep in sync.
- **`Permissions-Policy`** — it disables browser APIs only JavaScript can call, and this
  baseline ships none ([stack/html.md](stack/html.md)).
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

## Where the numbers come from

`VERSIONS.md` carries its own dated source list. Re-verify against those links,
never against memory or training data — and never against a search result that
does not name a version.
