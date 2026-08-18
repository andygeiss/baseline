# Verification Record

**Last verified: 2026-08-17**

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
   `gofmt`, `go vet`, `staticcheck`, and `govulncheck`, the canonical `Makefile`
   runs end to end under macOS's bundled GNU Make 3.81, and every measured color
   claim gets recomputed from its oklch values.
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

**Two commits since v3.9.0, and nothing a project reads changed in either.** The tag-gate
rewording of 2026-08-18 (`d80e015` — README and this file) and the budget decision of
2026-08-18 (README, the `Makefile`, and this file). Both are maintainer-only surface, so
neither owes a reference sync; they ride into the next release's record. v3.9.0 itself
closed its gate: twelve adversarial passes with the last two clean, the reference synced and
tagged in step at `cbba3c2`, `./verify.sh` exiting 0 against the commit its `SPEC.md` pins,
nothing a project reads changed between that commit and the tag, and the run recorded below.
**No budget is waived and `make tokens` is green.**

## Run log

Newest first.

### 2026-08-17 — four patterns, and the passes that rewrote them (v3.9.0)

**Forty-four defects over twelve passes**, the last two clean. The four documents that went
into the run are not the four that came out of it: every one of them was wrong about
something it stated confidently, and the count is the point — a first draft that reads well
is not evidence of anything.

**The empirical half:** [baseline-reference](https://github.com/andygeiss/baseline-reference)
`cbba3c2`, tagged v3.9.0, pinning baseline `12dc414` — the commit the documents survived
to. `./verify.sh` exits 0 there, over its full gauntlet plus eight new gates: the upload
that lies about itself, a picture round-tripped byte for byte, a long room paged backwards
with its two cursors kept apart, every time on a page machine-readable and naming its
zone, a reset link delivered and spent and ending the other sessions, that form answering
the same thing whoever asks, and two config pairs refused at boot.

**The worst one was a contradiction neither document could see alone.**
[htmx-lists.md](patterns/htmx-lists.md) said "the last item in the list is a control", and
[htmx-live-updates.md](patterns/htmx-live-updates.md) has said for three releases that the
last row of a list is the poller. **They cannot both be the last row.** A chat that pages
backwards fires both documents, follows both, and loses one of the two mechanisms. The rule
is now stated as *the far end from where new rows arrive*, with both directions spelled
out, because which end that is depends on the sort order and nothing had ever said so.

**Three more of the same shape — a rule stated once and contradicted elsewhere:**

- **`go-email.md` put the port and its fake in `domain`.**
  [go-ports-adapters.md](patterns/go-ports-adapters.md) rule 1 says the consumer declares
  the port, "never in the adapter and never in a `ports/` package of its own", and rule 6
  says the fake lives with the consumer's tests. Mail's consumer is the background sender,
  not a handler, and the new document now says that.
- **"A handler that names the actor" was in three places** — the uploads document's tier
  line, its checklist box, and the README's tier-1 list — and the reference cannot satisfy
  it. An attachment in a room everyone reads has no actor predicate, which
  [go-authorization.md](patterns/go-authorization.md) *Say which rows are shared* already
  allows. The rule is now "a handler rather than a file server", and **deleting** is where
  the actor comes back.
- **`security-headers.md` had anticipated this document and pointed nowhere.** It has said
  since v1.14.0 that user-uploaded files "MUST NOT be served from this path or this
  handler: that is a different route with its own `Content-Type` and `Content-Disposition`
  rules" — a forward reference to a document that did not exist until this run. It now
  names it.

**A fact that was true of one storage choice and stated as true of all.**
`time-and-dates.md` rule 1 justified itself with "`time.Local` is the container's UTC in
production and the developer's zone on their laptop". For a timestamp read back with
`time.Parse` from RFC 3339 that is simply false — the value carries the offset in the
string and renders identically everywhere. The zone that actually differs comes from
`time.Unix`, which returns a **local** Time, and [go-sqlite.md](patterns/go-sqlite.md)
offers Unix integers as one of its two storage choices. The rule was right; the reason
under it was wrong for half the projects that would read it.

**Two claims were checked by running them rather than by reading them.** `EXPLAIN QUERY
PLAN` against SQLite 3.54 refuted "the index matches the order exactly": an ASC index
serves a DESC keyset scan with the same `SEARCH … USING INDEX` and no temp b-tree, so the
document was telling readers to build indexes they do not need. The same check confirmed
the claim next to it — a row-value comparison really is used as an index range constraint,
rather than filtered after the fact.

**Nothing in [patterns/](patterns/) pointed at any of the four new documents.** Every
reference came from the checklist, the README, or this file. A reader inside
`go-auth-sessions.md` at "the plaintext token goes in the emailed link once" had no way to
reach the document that says how mail leaves. Four one-line back-links fixed it — and one
of them broke the floor budget, because `go-http-server.md` and `security-headers.md` are
*Required reading* and every byte in them is paid by every web application before its first
line of code. **The floor is the one budget that was never waived**, so the links were
trimmed and paid for out of the checklist. It holds at 19,499 of 19,500.

**The trim kept paying.** The change path finished the run at **7,237**, against 7,270
before any of this landed and 7,266 when the passes started: four new trigger sections, and
the number an ordinary change pays is 33 tokens smaller than it was. The checklist budget
and the change path stay waived under *Waived budgets*; the numbers there were re-measured
after the last fix of this run, which is the rule that entry states about itself.

**The question this corpus still cannot answer: how do you delete a person?** Uploads made
it sharp — an attachment is the first row that obviously outlives the account that made it,
and nothing here rules what happens to it, to their messages, or to the outbox row holding
their address when they ask to be gone. `go-sqlite.md` has cascade rules and no policy;
`go-authorization.md` says who may touch a row and not who may erase one. Every document in
this release is about data arriving. None of them is about data leaving.

### 2026-08-17 — the rule that was missing (v3.8.0)

The release that closed a tier-1 hole the corpus had carried its whole life.
[go-auth-sessions.md](patterns/go-auth-sessions.md) answered *who is signed in* in detail;
**nothing answered *may this actor touch this row*.** A handler rendering somebody else's
row passed every box in every checklist, and broken object-level access control is the most
common real vulnerability in the exact shape of application this corpus builds.

**Twenty defects over eleven passes**, the last two clean. Two came from the empirical half
and refuted rules this file had already accepted, which is the whole reason the reference is
a gate condition and not a nice-to-have. Two more were the shape defects that started the
release, and the check written for them now catches their whole class.

**How the gap was found is the part worth keeping.** Not by a pass over a document — by
asking what no document said. Twelve passes across v3.6.0 and v3.7.0 hunted contradictions,
traced snippets, and checked facts upstream, all of it work on files that exist. **A pass
now ends by naming the question the corpus cannot answer**, because absence is the defect
class a reader handed a file is structurally worst at.

**The release opened with two shape defects, and they are why `make structure` exists.**
[README.md](README.md)'s tree printed `llm-prompting.md` between the two `htmx-` documents,
breaking the alphabetical order [STYLE.md](STYLE.md) requires — in the tree of the file that
states the rule — and [patterns/pwa.md](patterns/pwa.md)'s tier-3 stamp had lost the four
words *so no waiver is needed* the other two tier-3 documents carry. **A claim of mechanical
checkability that nothing mechanically checks is a claim that decays.** Both sat in the layer
this corpus polices hardest, which is where a reviewer's eye has stopped seeing: twelve
passes over v3.6.0 and v3.7.0 read past both. `make structure` now walks the README tree
against the real directory and line 3 of all 35 [patterns/](patterns/) and [stack/](stack/)
documents against the one stamp format. It exits non-zero like `make tokens`, and like
`make tokens` it is an input to the adversarial half rather than a fifth condition —
**the gate keeps its four conditions.**

**What the empirical half refuted.** Both rules read well and did not survive a real
application:

1. **The private-by-default rule mandated a mechanism instead of an invariant.** It said
   "registered on a mux mounted behind `requireLogin`", which fits one class of private
   route under one prefix. The reference has three classes on paths that do not nest, and
   the mount silently loses the collection path: with only `/rooms/` registered,
   `GET /rooms` becomes a redirect to `/rooms/`, which the inner mux — holding
   `GET /rooms` — then 404s. Verified on Go 1.26.6 rather than argued. The rule now states
   the invariant — **a route's protection MUST NOT be optional where it is registered** —
   and gives both shapes: the mount for one class under one prefix, and a route table whose
   access class is a required positional field for anything else. The trap is written down
   where a reader meets it before the runtime does.
2. **"404 for somebody else's row" could not be met by a mutation that redirects.** Token
   revocation in the reference already did the right thing: its own 303 and "that token is
   already gone", which is the same sentence whether the row belonged to somebody else or
   was revoked in another tab. The rule is now that **the two answers match** and the status
   code follows the route. Never 403 stands, and it is why: a 403 confirms the row exists.

**What the adversarial half found.** Thirteen in this repository's documents over seven
passes, then three more in the reference's own files over the two after that. The pattern is
that the first pass over a new document catches it contradicting itself, and the later ones
catch it contradicting everything else:

- **A tier-1 document taught the wrong shape in required reading.**
  [go-http-server.md](patterns/go-http-server.md) said `requireAuth` goes "on protected
  route groups only" and showed a `Routes()` with no guard anywhere. It is one of the seven
  required-reading documents; the new tier-1 rule is a trigger document read later. The
  document paid first taught the shape the document paid later forbids. Found in pass 7,
  and the latest-found defect of the run by six passes.
- **The document's own tier line contradicted two rules the run had just rewritten**, and
  rule 6 still said "the same 404" after rule 4 stopped saying 404. Both in pass 1: a
  rewrite leaves its own summary behind.
- **The mount snippet used `pub` without declaring it** — a variable lost in the rewrite.
- **The testing section told a reader to assert 404 on write routes.** A write that
  redirects cannot. It now says to assert the route's own answer *and* that the row did not
  move, because a refused write and a successful one can share a status code.
- **[README.md](README.md)'s tier-1 enumeration omitted the new document.** That section
  says in its own words that a rule meeting the test and missing from the list is still
  tier 1 and the list is the defect. It was.
- **The checklist section claimed to be wholly tier 1 while holding a tier-2 box** —
  naming the shared rows is shape, not safety. Moved to the preamble's partly-tier-1 list.
  This is the v3.7.0 defect class, one release later, in a section written by the person
  who had just read the v3.7.0 entry.
- **The `❌ ownership in a middleware` bullet restated a rule the document had already
  made.** Deleted, per *Write to the reader's competence*.
- **A version-dependent status code stated flatly.** The trailing-slash redirect is 307 on
  Go 1.26; the document now says so rather than implying it is eternal.
- **The waiver's own numbers went stale twice inside the run that wrote them** — first
  after the fix passes, then again after the fix for that. Waiver numbers are now measured
  last. The recurrence is recorded because it is the run's clearest lesson about ordering.
- **Three smaller ones**: the sibling document not pointing forward
  ([go-auth-sessions.md](patterns/go-auth-sessions.md) now does), a checklist box holding
  two checks against *One box, one check*, and the corrected rule 4 leaving a stale summary
  line in the checklist's own section header.
- **Then the pin itself, in pass 8.** The reference's `SPEC.md` named the commit where the
  two refuted rules were fixed — and seven passes of fixes came after it. **A reference
  pinned to a superseded commit claims a green gate against documents nobody shipped**, and
  it would have satisfied conditions 2 and 3 while doing it. Found by re-reading the pin
  against this repository's log instead of trusting a hash written an hour earlier. The pin
  is the one field in this whole protocol that cannot be checked by reading the file it
  sits in.
- **Two in the reference's own prose, in pass 9**: the same flat 307 the baseline had just
  corrected, and an ambiguous "that repository". A run that fixes a class of defect in one
  repository should grep the other for it, and this one had not.

**The floor was the run's real constraint, and it did not bend.** Wiring the new rule into
required reading cost the floor budget 85 tokens against 52 of headroom — 33 over. Rather
than waive the number [README.md](README.md) calls the one that actually hurts, the pointer
was tightened and a duplicate paid for the rest: `go-http-server.md` had restated the
`SameSite=Lax` second-layer fact that
[security-headers.md](patterns/security-headers.md) owns and cross-references, and both
documents are required reading, so the copy was duplication inside one read path. Floor
closes at **19,498 of 19,500**. Two tokens. **The floor is now full**, and the next tier-1
document that has to be reachable before the first line of code is a trade, not an
addition — that is the finding this release leaves for the next one.

**The empirical half.** Reference synced and tagged **v3.8.0** (`ba60701`), `SPEC.md`
pinning **`5538323`**, `./verify.sh` **exit 0 over 61 gates** — 60 before this release. The
pin names the commit that carries the final documents; the tag here sits one commit later on
this file, which adds no rule — the same shape as v3.7.0, and the reason condition 2 is
satisfied by a pin that is not the tagged commit.
What changed there: `internal/app/routes.go` moved from wrapping each handler to one route
table whose access class is a required positional field, with `guard` panicking at boot on
a class it does not know; `internal/app/routes_test.go` walks that table so a route added
without a guard fails there instead of serving, and pins the public surface at six routes;
`README.md` gained *Who owns what*, naming `tokens` and `users` as owned and `rooms` and
`messages` as shared on purpose.

**Every new check was verified by breaking the thing it checks**, not by watching it pass:

- `make structure` was run against a copy of the v3.7.0 tree and caught both mechanical
  defects, a new pattern missing from the README tree, and a retired one still printed in it.
- The route-table test was run with `GET /profile` marked `public` and named it.
- The new `verify.sh` gate was run with the `user_id` dropped from the token `DELETE`. The
  store test caught it first, so the gate never ran — muting that test proved the gate
  fails on its own, naming the missing clause.

**What the reference already did right is where the document came from.** `Tokens.Delete`
has taken the actor as a parameter and carried `user_id` in the `WHERE` clause since machine
tokens existed, `ByUser` scopes the list, and a cross-user revocation test existed at both
layers. The pattern is mostly that code, written down and made general — which is the
direction this corpus is supposed to run in.

### 2026-08-17 — the router folded into the checklist (v3.7.0)

The release that ended the router two days after inventing it. v3.6.0 measured what an
agent reads; this one attacked the largest number that measurement produced — **an
ordinary change to a conforming project**, which is the thing anyone does most often and
was paying 8,091 tokens for a web application.

  ordinary change   8,091 → 6,980 tokens   (−14%)
  floor + checklist 20,287 → 19,182        (−5%)
  reach             87,445 → 80,822        (−8%)
  hot corpus        95,068 → 91,918 · 51 → 48 files

**Seven defects over twelve adversarial passes**, the last two clean. Two of the seven
were introduced by the run's own fixes and caught by the pass after — the same ratio, and
the same lesson, as v3.5.0: run the pass after the one that looks finished.

**The router and the checklist were the same rows with different payloads.** Every one of
the twenty documents a checklist bold-bullet named was already a router row; one said
*read this*, the other said *and this is what done looks like*. They are one file per
project type now, one section per topic: the moment it fires in gerund form, the document
that rules it, and the boxes it is checked against. A change reads the sections it fires
and gets both halves in one hop; a milestone walks the same file's boxes. The routers
split out for v3.6.0 never shipped — they existed only in a working tree, so nothing
downstream ever saw them.

**The fusion made a defect class unrepresentable, and caught one on the way in.** A row
pointing at a document no box checks cannot be written any more, because the row *is* the
box's heading. Wiring the CLI checklist surfaced exactly that: its router had pointed at
[patterns/go-sqlite.md](patterns/go-sqlite.md) since it existed and **no box ever checked
it**. Three boxes added, verbatim from that document. This is the v3.5.1 failure — *a
pattern nothing pointed at* — caught by structure rather than by a reviewer, which is the
only kind of fix that keeps working after everyone stops paying attention.

**Write to the reader's competence**, a new rule in [README.md](README.md) *Size budgets*.
The reader is a capable Go engineer, and every line spent on what it already knows is a
line it pays to skip. The test is one question: *would a competent engineer get this wrong
from the rule sentence alone?* No for `sleep`, `jitter`, `retryAfter`, `idempotent`,
`retryableStatus`, a table test, a `main` switch, `readCredential` — so the contract is
the payload and the body is overhead. Yes for `http.DefaultClient` having no timeout, `Do`
returning nil for a 500, a nil `GetBody` replaying an empty body the server accepts — so
those stay in code. [patterns/go-http-client.md](patterns/go-http-client.md) fell
4,573 → 3,774 with its code half halved. [patterns/design-system.md](patterns/design-system.md)
was held against the same test and left alone: its 120-line `DESIGN.md` template *is* the
payload, and the test says so.

**The same test governs an anti-pattern list.** 2,627 → 2,129 words across twenty
documents. Every ❌ naming something a reader would otherwise reach for (resty, viper,
Google Fonts, an icon font, gomock) stays, as does every one carrying a fact stated
nowhere else; every ❌ that inverts a rule the document already made is gone, because that
is duplication inside a single read path. `go-background-work.md` and `llm-prompting.md`
lost the section entirely — every bullet restated a rule from a paragraph earlier.

**What the adversarial half found.** Seven defects, all fixed. The first is the one that
mattered:

1. **Thirteen tier-1 boxes silently became waivable.** Tier 1 was defined positionally —
   "everything under *Security* in the checklists" — and the fusion scattered those boxes
   across the topic sections that fire them: session cookies, machine tokens, argon2id,
   auth rate limiting, constant-time login, parameterized SQL, and the icon CSP check all
   left *Security* for a section the preamble did not name. v3.6.0 had already replaced
   the positional *definition* with a test; it left the positional *enumeration* in place,
   and the fusion is what turned that into a safety hole. A wholly tier-1 section now says
   so in its heading, and the three partly tier-1 sections name their boxes in the
   preamble.
2. **[README.md](README.md)'s tier-1 list still pointed at sections that no longer
   exist** — *Security* and *Code quality*. Rewritten to name what each rule protects and
   to say the checklists mark tier 1 rather than imply it.
3. **Five documents claimed their rule lived "under *Security*" in a checklist.**
   `go-auth-sessions`, `security-headers`, `go-sqlite`, `htmx-server-rendering`, and
   `go-forms-validation` now say *tier 1 wherever a checklist files it*. Two of the five
   were found only after a broader grep than the one that found the first three — the
   first pattern searched for `under *Security*` and missed `the checklists' *Security*
   section`.
4. **One rule narrowed.** *Every form control labeled* had moved from an unconditional
   section to *Accepting a form POST* — but a GET-only search box has form controls and
   fires no such trigger. Back under *Every web application*. This is the fusion's
   characteristic failure mode, and the pass that found it was the one that enumerated
   every box that moved from an unconditional section into a conditional trigger. Every
   other such move lands on a trigger that fires for effectively every project of the type
   (writing CSS, laying out a page, rendering a response, writing a test) or is genuinely
   conditional (icons, web fonts, a glossary, secrets).
5. **Two budget regressions, both introduced by the fixes above**, both caught by the next
   pass: the tier-1 preamble put the change path 50 tokens over, and the sentence
   explaining defect 4 put it 13 over. Fixed by cutting rationale out of the most-paid
   document in the corpus rather than by raising the budget to fit — a budget raised to
   accommodate its own author's growth is not a budget.
6. **The v3.6.0 entry overstates its gate count.** It records **61 gates**; `verify.sh` is
   byte-identical to the v3.6.0 tag and runs **60**. Same bookkeeping class as the count
   defect v3.5.0 found, and the reason that run's standing check exists.

**No rule was lost, and here is how that was checked** rather than asserted. Checklist
boxes reconcile at **306 → 307**: minus two duplicates merged in web-application (a second
*No service worker*, and a backups box that restated the ship-section one), plus three
from defect-class item 2. Every pre-fusion box was then matched to a counterpart in the
fused files by keyword, all 306 accounted for. RFC-2119 keywords in governing documents
hold at **135 → 136**, the one addition being a `MAY` permitting a trigger section to
carry no box where the document rules something no milestone can verify. The first
matcher written for this check was itself defective — it required three keywords, so every
short box failed it — which is worth recording: *a clean result from a check nobody
validated is not evidence.*

Every trigger section names a document that exists; every `patterns/`, `stack/`, and
`operations/` document is reachable from a checklist or a *Required reading* list; every
markdown link in the corpus resolves; no checklist repeats a box; and the v3.5.0 standing
check on undeclared identifiers passes for both documents item 3 touched.

**Empirical half: closed, before the tag.** No rule this repository implements changed,
which is the claim the run had to test rather than assume — so the three new CLI
`go-sqlite` boxes were traced: SQLite in the reference lives only in `cmd/server` and
`internal/store`, the `gochat` client stores nothing between runs, the trigger never
fires, and those boxes are **unexercised** there rather than failing. Reference synced and
tagged v3.7.0 (`23a54fd`), its `SPEC.md` pinning this release's commit `8795f18`.
`./verify.sh` exits 0 — **60 gates**, mechanical checks through both booted binaries and
the full smoke suite, run against the exact commit being tagged.

### 2026-08-17 — what the corpus costs to read (v3.6.0)

The release that measured the corpus against the thing nobody had been measuring: **what
an agent has to read before it writes a line.** *Retiring a pattern* capped how many
documents exist; nothing capped how big one got, and the answer had grown to 29,855
tokens of required reading for a web application.

  web application   29,855 → 18,252 tokens
  cli tool          18,384 →  9,801
  library           16,604 → 11,580

**Two defects over three adversarial passes**, the last two clean. Both defects were
losses the sweep itself introduced, which is the risk of a prose rewrite and the reason
the first pass attacked exactly one claim: *no rule was removed*.

**No rule was removed, and here is how that was checked** rather than asserted. Every
RFC-2119 keyword in the corpus was counted before and after — 129 both times — and the
five files whose local count moved were read line by line against their pre-sweep
versions. Three of the five were relocations (the RFC-2119 sentence into
[SKILL.md](SKILL.md), a rewrap, a heading rename). **Two were real losses:**

1. **[patterns/go-config.md](patterns/go-config.md) rule 1 dropped a MUST NOT.** "A bad
   `PORT` MUST NOT be discovered by a half-started process that already created files"
   was gone; the rewrite had kept the timing and lost both the normative force and the
   consequence that explains it. Restored.
2. **[patterns/design-system.md](patterns/design-system.md) dropped a MAY.** The
   permission to use a Claude Design sync integration where one exists had been
   compressed away with the sentence around it. Restored.

The later passes attacked different surfaces and found nothing: all 125 code blocks are
byte-identical except the one deliberately moved and re-commented; every one of the nine
headings that disappeared is accounted for by a move or the run-log compression; every
cross-document `rule N` reference still lands on the rule it names; every required-reading
entry and all 41 trigger rows resolve; no document still claims to own something that
moved.

**What changed structurally.** [SKILL.md](SKILL.md) is now the whole agent protocol and
[README.md](README.md) is the maintainer's document, out of the read path — the protocol
used to be stated in both, and a protocol stated twice drifts in one copy. Six documents
left *Required reading* for trigger rows against one test: does this change a decision
made before the first line of code? `security-headers` stayed required despite a clean
trigger, because it is tier 1. The timeout ladder moved to
[patterns/go-http-client.md](patterns/go-http-client.md) and the LLM prompt rules to
[patterns/go-llm-adapter.md](patterns/go-llm-adapter.md), each to where its trigger fires.
The `Rule tier:` boilerplate, byte-identical in 26 files, became a stamp. This file's
older run narratives compressed into *Earlier runs*, keeping the counts and the findings
that would otherwise be re-litigated.

**Size budgets are the part that stops the regrowth** — 2,500 tokens of prose per
document, 19,000 per project-type floor, enforced by `make tokens` and calibrated to the
swept corpus so they ratchet rather than aspire. Fenced code is excluded: a snippet is the
payload, not the overhead. **One document is over on purpose.**
[patterns/go-llm-adapter.md](patterns/go-llm-adapter.md) holds 3,155 tokens of prose —
twenty numbered rules, not padding — which is the budget saying it owns two subjects, the
adapter shape and the model-specific traps. Splitting it is the next release's work; it is
recorded here rather than solved by shaving prose to make a number, which the first draft
of this sweep did to two other files before catching itself.

**Tier 1 is now defined by what a rule protects** (`fix`, and the answer to an owed
adjudication). The old definition was positional — "everything under *Security* in the
checklists" — while three secret-handling rules met every part of the tier-1 test from
under *Code quality*. The test is the definition now, the enumeration is what the test
currently catches, and the web and CLI checklists say in their preambles that those three
boxes are unwaivable where they sit. No box moved sections, and no rule changed tier by
judgment.

**Empirical half: closed, before the tag.** No rule this repository implements changed, so
the reference needed no code change — which is itself the claim the run had to test rather
than assume. Reference synced and tagged v3.6.0, its `SPEC.md` pinning this release's
commit `60849e5`. `./verify.sh` exits 0 — **60 gates** (corrected from 61 by the v3.7.0
run: `verify.sh` is byte-identical to this tag and has 60 `step` call sites), mechanical
checks through both
booted binaries and the full smoke suite, run against the exact commit being tagged.

### Earlier runs

Compressed to what a future reader still needs: the counts, and the findings that would
otherwise be re-litigated. The full narratives are in this file's git history.

**The three newest runs stay in full; everything older lives here.** A run log that only
grows costs more to re-read than it saves, and the compression is what keeps a narrative
from being re-litigated a year after it was settled.

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

## Where the numbers come from

`VERSIONS.md` carries its own dated source list. Re-verify against those links,
never against memory or training data — and never against a search result that
does not name a version.
