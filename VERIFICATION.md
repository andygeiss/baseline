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

**Owed since 2026-08-18.** v3.10.0 closed its gate — eleven adversarial passes with the
last two clean, the reference synced and tagged in step at `dadfb2f`, `./verify.sh`
exiting 0 against the commit its `SPEC.md` pins, and the run recorded below. Six changes
have landed since, and none has been through a run:

- [SKILL.md](SKILL.md) *Handing the work back* — every piece of work ends with the next
  steps. A protocol rule, so it has no checklist box and no reference to implement it.
- [patterns/go-background-work.md](patterns/go-background-work.md) — the second shape,
  work a request starts and does not wait for.
- [patterns/htmx-live-updates.md](patterns/htmx-live-updates.md) — *When the polled thing
  is not a list*, which gives way on rule 3 for a region that is not one.
- [patterns/go-llm-adapter.md](patterns/go-llm-adapter.md) — the streaming port, rule 8's
  late refusal, rule 16's per-adapter count.
- [checklists/web-application.md](checklists/web-application.md) — the schedule section
  widened to route to the first of those, and the polling cursor box generalised.
- The floor budget, 19,500 → 25,000, under *Budget decisions*.

**No budget is waived and `make tokens` is green.** What is owed is the review. No
adversarial pass has read any of it, the Go snippets in the new sections have not been
compiled, and [baseline-reference](https://github.com/andygeiss/baseline-reference)
implements none of it — detached work least of all, which is the shape the empirical half
exists to catch, since its trap is a shutdown that looks clean.

## Run log

Newest first.

### 2026-08-18 — the document for data leaving (v3.10.0)

Every document in this corpus ruled data arriving. Nothing ruled a person leaving: what
happens to their attachments, their queued mail, and the session their browser is still
holding. [patterns/go-data-deletion.md](patterns/go-data-deletion.md) is tier 1 and closes
that. The release also settled the budget tension v3.9.0 recorded and could not resolve.

**Eighteen defects over eleven adversarial passes**, the last two clean. Three of the
eighteen came from building the rules rather than from reading them, and that split is the
finding about the process: the readings caught wording, scope and missing citations, while
only running the rules caught the two places where they were *wrong*.

**The budget decision came first, and alone.** v3.9.0 left `checklists/web-application.md`
at 4,509 of 4,300 and the change path at 7,237 of 7,000, with a finding rather than a
promise attached: the prose was already at the bar *Write to the reader's competence* sets,
and what remained was boxes and one-line section leads. Andy raised the two numbers to
5,000 and 8,000 in a commit that moved nothing else. The argument, the three branches not
taken, and the signal that says which one to take next time are under *Budget decisions*.
**The floor did not move**, so the new checklist section was paid for out of the seven
required documents: `patterns/go-http-server.md` lost a repeated timeout block, a forward
reference to the bullet below it, two comments restating their own code, and the upload
cap-site fragment, which moved to [patterns/go-file-uploads.md](patterns/go-file-uploads.md)
where an upload route is actually written. 19,487 of 19,500.

**Three rules did not survive contact with the reference.** All three are fixed in the
tagged commit.

1. **The all-tables sweep does not find what it looks like it finds.** The document's
   headline test reads `sqlite_master` at runtime and looks for the deleted id in every
   text column — and it matches rows that name the person *by id*. The outbox holds an
   address and, at that moment, no `user_id` at all, so it stayed green while the address
   stayed on disk. Proved by deleting the column and watching the sweep pass. The rule now
   says the sweep finds references, not copies, and asks for a by-value assertion beside it
   on the columns holding a person's data under another name.
2. **The schema is only the delete if the first migration got it right.** SQLite cannot
   alter a constraint, so changing an `ON DELETE` action is create-copy-drop-rename — and
   `DROP TABLE` with foreign keys on runs an implicit `DELETE FROM` that *does* fire
   foreign key actions, so dropping a parent to rebuild it takes its children with it. The
   usual escape is closed to a migration inside one transaction, where `PRAGMA
   foreign_keys` is a no-op. Both facts are now cited. This is also why the reference keeps
   **erase** for its messages rather than moving to **anonymize**: that answer is free
   before the table ships and expensive after.
3. **An anti-pattern was too wide.** "A confirmation that is a JavaScript dialog" would
   have banned the `hx-confirm` the reference already uses on its token revoke, which is an
   htmx attribute rather than hand-written JavaScript and is right for an action somebody
   can redo. The rule now names what actually matters: an irreversible action asks for
   something the *server* can check, and `hx-confirm` is nothing on the wire.

**One rule the reference had already met**, which is the other kind of useful answer.
`authenticate` resolved a session to a user row and destroyed the session when the row was
gone, with the comment "the account is gone but the cookie is not" — written long before
this document asserted it. Sessions are the hole no cascade reaches, because the row is
keyed by token and its payload is opaque to SQL; the fix is not a column on the session
table but the middleware loading the row. That rule shipped already proven.

**The defect class the last two passes kept finding was a stale claim elsewhere.** Making
an account deletable made two sentences false that nothing pointed at:
[patterns/glossary.md](patterns/glossary.md)'s example entry said a message is "never
edited, never deleted", and the reference's *Who owns what* row said the same. Both fixed,
and the glossary example stays character-identical to the reference's file. **A new
capability falsifies prose in documents it never touches**, and neither `make structure`
nor `verify.sh` can see it — the sweep is a grep for the claims the change contradicts.

**A box that was deliberately not added.** The by-value assertion from finding 1 has no
checklist box of its own: the floor had thirteen tokens of headroom and a seventh box costs
about twenty. Its concrete instance — outbox rows carrying an address — *is* boxed, and the
general rule is in the document the section routes to. Recorded rather than quietly
dropped, because "the checklist did not check it" is how a rule goes missing.

**Empirical half: closed before the tag.** The reference could not delete a person at all,
which is how the gap was found. It gained `/account/delete` — a page, not a dialog, asking
for the account name retyped and the password, both checked by the server — one migration
adding the outbox's `user_id` and an index on each of the five child columns, four handler
tests, the schema sweep, and three new `verify.sh` gates: every user column declares an
`ON DELETE` action, every child of `users` is indexed table-by-table, and the delete
confirmation is server-checkable. **Both assertions of the sweep were proved to fail before
they were trusted** — removing a cascade reddens the id sweep, removing `outbox.user_id`
reddens the by-value check while the id sweep stays green. Reference synced and tagged
v3.10.0 at `dadfb2f`, its `SPEC.md` pinning `c1ca89f`, `./verify.sh` exit 0.

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

### Earlier runs

Compressed to what a future reader still needs: the counts, and the findings that would
otherwise be re-litigated. The full narratives are in this file's git history.

**The three newest runs stay in full; everything older lives here.** A run log that only
grows costs more to re-read than it saves, and the compression is what keeps a narrative
from being re-litigated a year after it was settled.

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
