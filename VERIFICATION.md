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

**No tag ships until all four are true.** This is a gate, not a goal.

1. Two consecutive adversarial passes over the changed documents find zero defects.
2. The reference implementation is synced to the change, and `./verify.sh` exits
   0 against the exact baseline commit being tagged.
3. The reference's `SPEC.md` pins that commit, and its own tag mirrors the
   baseline version.
4. The run is recorded below, naming the reference commit and the `verify.sh`
   result.

**A release note that says "the reference was not re-synced" is not a waiver —
it is an unfinished release.** That sentence appeared in two consecutive runs
before this gate existed, which is why the gate exists. If the reference cannot
be synced, the tag waits.

## Owed: changes not yet through a run

**Owed: two shape defects, and the check that now catches them.** **No tag until a pass
has run.** No rule was added, removed, or reworded, so the pass over the documents is
short — but `make structure` is new code in a repository that has almost none, and that
is where a pass should look.

1. **Two defects an eye missed and a machine would not have.** [README.md](README.md)'s
   tree printed `llm-prompting.md` between the two `htmx-` documents, breaking the
   alphabetical order [STYLE.md](STYLE.md) requires — in the tree of the file that states
   the rule. [patterns/pwa.md](patterns/pwa.md)'s tier-3 stamp had lost the four words
   *so no waiver is needed* that the other two tier-3 documents carry. Both fixed.
2. **`make structure` checks the two claims this repository makes about its own shape.**
   The README tree against the real directory, two levels deep, and the tier stamp on
   line 3 of all 34 [patterns/](patterns/) and [stack/](stack/) documents against the one
   format *Which rules can be waived* prints. Verified against a copy of the v3.7.0 tree:
   it catches both defects above, a new pattern nobody added to the tree, and a retired
   one still printed in it — which is step 3 of *Retiring a pattern* enforced rather than
   remembered. It exits non-zero like `make tokens`, and like `make tokens` it is an input
   to the adversarial half rather than a fifth condition on the gate: **the gate keeps its
   four conditions.**

**The lesson is the one the router fusion already taught.** A claim of mechanical
checkability that nothing mechanically checks is a claim that decays, and both defects
were in the layer this corpus polices hardest — which is where a reviewer's eye has
stopped seeing. Structure caught them; five adversarial passes over v3.6.0 and v3.7.0 did
not.

### Open finding: no document rules object-level authorization

Not a change, and not owed to the run above — nothing here addresses it. Recorded here
because this file is what an audit reads, and the baseline has no tracker.

[patterns/go-auth-sessions.md](patterns/go-auth-sessions.md) answers *who is signed in*
thoroughly: argon2id, renewal on login and password change, rate limiting, constant-time
login, machine tokens hashed at rest. **Nothing anywhere answers *may this user act on
this row*.** No document says a query for a user-owned resource filters by the session's
user ID, or that an ID from the URL is untrusted input. A handler that renders
`GET /games/{id}` for another user's game passes every box in every checklist today.

By the tier-1 test — a rule is tier 1 when dropping it loses data, leaks it, or hands
over an account — that gap is tier 1, and broken object-level access control is the most
common real vulnerability in exactly the shape of application this corpus builds. Closing
it needs its own pattern document, a checklist section that fires on every handler
reading a user-owned row, and the reference implementation exercising it. Raised
2026-08-17.

## Run log

Newest first.

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

### 2026-08-17 — a pattern nothing pointed at (v3.5.1)

The release that wired up a document the protocol could not reach.
[patterns/local-https.md](patterns/local-https.md) shipped inside v3.5.0 with no
trigger row, no checklist box, and no line in this file — 204 lines of rules an agent
following [README.md](README.md) top-down would meet only if it happened to be
building a PWA. **Seven defects over five adversarial passes**, the last two clean.
Six of the seven were in the fix rather than in the corpus, which is what a small
change reviewed properly looks like.

**No rule changed.** Every box carries a rule
[patterns/local-https.md](patterns/local-https.md) already stated; the document was
re-read clause by clause against the boxes to prove it. That is also why this is a
patch and not a minor: the corpus gained navigation and enforcement, not rules.

**What the fix added.** A trigger row in
[project-types/web-application.md](project-types/web-application.md), placed after the
install row. Six boxes in [checklists/web-application.md](checklists/web-application.md)
— one unconditional in *Stack compliance*, five in a conditional block in *Code
quality* beside the `.env` block it matches in kind. Web only: a CLI or a library has
no browser, and the document says so itself.

**What the passes found.**

1. **The TLS rule was conditional, and the rule is not.** *The binary MUST NOT serve
   TLS* was first written inside the opt-in block, so a project that never adopted
   local HTTPS was never asked whether it had grown a `-tls-cert` flag — the one
   anti-pattern the document exists to prevent. Moved out to *Stack compliance*, where
   it is asked of every web application.
2. **A box that could not be answered.** "That local authority signs nothing a user
   touches" states a rule but is not a check. Rewritten to name what a walker looks
   at: nothing a user visits is served with a certificate it signed.
3. **A box that named a file the walker cannot see.** "an edited copy of the operations
   repository's template" now names the path, `baseline-ops/templates/Caddyfile`, so
   the check is a diff rather than a memory.
4. **The trigger row's list was short.** It named camera, microphone, geolocation,
   passkeys and install, and the document's table also carries notifications. Added.
5. **The reference's own waiver read as violated.** *Never deployed* said the
   deployment end is absent — "no image, no compose file, **no Caddy**" — and this
   change adds a Caddyfile. The waiver now says *no deployment Caddyfile* and states
   why the local one does not narrow it. A waiver that looks broken is a waiver nobody
   trusts.
6. **A verify.sh gate that would fail correct code.** The TLS gate grepped for
   `crypto/tls`, which every outbound client that pins its own roots would trip. The
   rule bans *serving* TLS, not using it, so the gate now looks for the serving calls.
   A gate that cries wolf is deleted by the next person who meets it.
7. **A comment that claimed a run CI does not do.** The skip branch said "CI installs
   Go and nothing else"; CI runs the seven `make check` gates directly and never runs
   `verify.sh` at all.

**The empirical half went further than the gate asks.** Go Chat is installable and has
no other secure-context feature, so the trigger fires for it and the reference adopts
the pattern rather than recording it unexercised: `Caddyfile.lan` character-identical
to the document's snippet, a `lan` target, the opt-in in its README, and six new
`verify.sh` gates (54 → 60). Five of the six boxes are now machine-checked.

**Then it was run, not read.** Caddy 2.11.4 in front of the real binary, on this
machine, today: `ssl_verify_result=0` against the local root, the app answering
through the proxy (`<title>Sign in · Go Chat`), and the proxied and direct response
bodies **byte-identical** — the sharpest evidence that the binary is not made to know
a proxy is there. `:80` stayed unbound, so `auto_https disable_redirects` does what
the document says. Both of the document's numeric claims reproduced a day after it
was written: the served certificate is valid **12 hours**, the root **10 years**. The
run used port 8444 rather than 8443, because a Caddy started on 2026-08-16 still held
8443; the config was generated from the committed file by `sed` and the diff printed,
so the only difference was the port.

**Empirical half: closed, before the tag.** Reference synced and tagged v3.5.1, its
`SPEC.md` pinning this release's commit. `./verify.sh` exits 0 — 60 gates, including
the six new ones.

### Earlier runs

Compressed to what a future reader still needs: the counts, and the findings that would
otherwise be re-litigated. The full narratives are in this file's git history.

**The three newest runs stay in full; everything older lives here.** A run log that only
grows costs more to re-read than it saves, and the compression is what keeps a narrative
from being re-litigated a year after it was settled.

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

Why each absent header stays absent:

- **`X-Frame-Options`** — superseded by `frame-ancestors`, honored by every browser in
  the support window. Two headers saying one thing is one more to keep in sync.
- **`Permissions-Policy`** — it disables browser APIs only JavaScript can call, and this
  baseline ships none ([stack/html.md](stack/html.md)).
- **`object-src 'none'`** — `default-src 'self'` already denies cross-origin plugin
  content, and the app embeds none.
- **CSP reporting (`report-to`)** — needs an endpoint and somebody to read it. Add it
  when a real policy question needs real data.

## Where the numbers come from

`VERSIONS.md` carries its own dated source list. Re-verify against those links,
never against memory or training data — and never against a search result that
does not name a version.
