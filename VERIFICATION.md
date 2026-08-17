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

**Nothing owed.** v3.6.0 closed every item that stood here: the token sweep and the tier-1
adjudication went through the run recorded below, and the `VERSIONS.md` re-verification
shipped as its own `fix` in the same release.


## Run log

Newest first.

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
commit `60849e5`. `./verify.sh` exits 0 — **61 gates**, mechanical checks through both
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

### 2026-08-17 — the LLM adapter, the timeout ladder, one box one check (v3.5.0)

The release that gave the corpus a shape for AI capability and a rule for
subtraction. **Seventeen defects over twelve adversarial passes** — the last two
clean, which is what the gate asks for. Two came from the first two passes,
fifteen from passes three through ten (twelve in the corpus, three introduced by
the fixes and caught by the pass after). A run this long is what a new document
plus eight edited ones costs; the count is recorded rather than rounded down.

**The corrections did not move the reference.** Every one either sharpened prose,
named a consequence, or fixed a snippet's completeness; the two that touch rules
— the AI token ceiling reaching the CLI checklist, and the `/healthz` version box
— leave Go Chat conforming (its ladder is a 10 s budget under a 15 s client
timeout under the canonical 30 s `WriteTimeout`, and it releases from clean tagged
checkouts). The CLI token-ceiling box is *unexercised* there rather than failing:
the assistant lives in the server, and the `chat` client calls no model.

**What the adversarial half found.** First, two defects, both fixed:

- **[operations/web-application.md](operations/web-application.md) contradicted
  the reader it had just declared canonical.** It said a missing `.git` means
  "every binary just reports `unknown`. A version of `unknown` at `/healthz`
  means one of the two" — but the canonical web-application reader is
  `resolveVersion`, which never returns `unknown`; it falls through to a boot id.
  The real symptom is a `/healthz` version that changes on every restart, and
  `unknown` there now means the opposite thing: the wrong reader is wired in.
  This is exactly the dangling claim the *attack first* note below predicted.
- **[patterns/go-config.md](patterns/go-config.md) rule 7's snippet did not
  compile.** It formatted an error with `beside` and never defined it. The
  snippet now derives it (`voices/jarvis.opus` → `voices/jarvis.txt`).

**What the later passes found.** Twelve more, all fixed. The three that were
wrong rather than untidy:

1. **[patterns/go-llm-adapter.md](patterns/go-llm-adapter.md) rule 5 promised a
   vendor behavior that is not current.** It said two user turns in a row draw a
   400. Held against the `claude-api` skill, consecutive same-role turns are
   accepted and merged into one; what actually binds is user-first. The rule now
   says the shape to send and refuses to promise what any vendor does with a
   worse one — which is also the document's own scope rule, applied to itself.
2. **The timeout ladder's own example does not fit the ladder.** `turnBudget =
   90 * time.Second` sits above the canonical 30 s `WriteTimeout` *and* the
   canonical 10 s outbound `http.Client.Timeout`, so a reader who copies it
   verbatim builds the first failure the section warns about. The snippet now
   names both consequences where the constant is declared.
3. **The ladder and the retry policy disagreed, silently.** A client timeout at
   or above the budget means `Timeout` never fires first, so the retry loop in
   [patterns/go-http-client.md](patterns/go-http-client.md) cannot run inside a
   budgeted handler. Both documents were right alone and unresolvable together;
   the ladder now states the trade.

The rest: rule 8's snippet spelled a vendor stop-reason the document delegates
to the skill (now one named constant, which is what "the adapter is where that
vendor word disappears" looks like in code); `systemctl show` in
[patterns/go-config.md](patterns/go-config.md) rule 7, written **two days** after
systemd left this corpus with the operations split — a retired concept walks
back in through a new document's prose, not through the documents the extraction
swept; [STYLE.md](STYLE.md)'s first error-message example not quoting the value
its own next bullet says to quote with `%q`; the lazy-lookup snippet in
[patterns/go-http-client.md](patterns/go-http-client.md) using three fields the
`Client` struct that document shows never declares; the AI token ceiling — a
silent truncation bug — enforced in the web-application checklist and not in the
CLI one; a `/healthz` box still reading "not `unknown`" after item 1
established that the canonical reader cannot answer `unknown` (the dangling
claim the *attack first* note predicted, found in the checklist rather than the
document); and three bookkeeping defects in this file — a change count of eight
against nine listed changes, checklist box counts that no `git grep` reproduces,
and README's new *Retiring a pattern* missing from a section whose whole job is
to list what is owed a run.

**Three more were introduced by the fixes themselves and caught by the next
pass** — fifteen fixed in all, and that ratio is the argument for running the
pass after the one that looks finished. One left `refusalStopReason` undefined in
a snippet, repeating the exact defect class this run had already fixed once in
`go-config.md`; one opened a second permitted timeout shape that no checklist
box could express, withdrawn rather than enforced; and one asserted in a comment
that the example budget *is* shorter than the write timeout, which is only true
once the reader has done what the next paragraph tells them to.

**Undeclared identifiers were the run's most repeated defect** — three times, in
three documents: `beside` in `go-config.md`, `refusalStopReason` in
`go-llm-adapter.md`, and `voice`/`mu`/`resolved` on the lazy-lookup `Client` in
`go-http-client.md`. Worth a mechanical check next run: every identifier a
snippet uses is declared in that snippet or in one the same document shows.

**Item 1's snippet is now verified by execution, not by reading** — the thing the
*attack first* note asked for. `resolveVersion` was compiled, vetted and run
against Go 1.26.6 over every shape the toolchain produces, and the shapes
themselves were produced rather than assumed: a real module built tagged
(`v0.3.0`), tagged-and-dirty (`v0.3.0+dirty`), untagged (`v0.0.0-<ts>-<sha12>`),
untagged-and-dirty (…`+dirty`), with `-buildvcs=false` (`(devel)`, no `vcs.*`
settings), and with no commits at all. All six land where the corpus says: a
per-commit-unique string when there is one, the 12-character revision for a clean
checkout, a fresh boot id otherwise — and `min(len(revision), 12)` holds for a
short revision. The `+dirty` and `(devel)` shapes the note singled out are
confirmed against the toolchain rather than against this text.

**The other new snippets were compiled too**, against the same toolchain: the
lazy lookup, `janitor` with its run-once and its `context.Canceled` branch, the
paired-setting check, and the refusal translation — `gofmt`, `go vet`, and
`go build` clean. The paired-setting check was then *run*, and the error it
produces is character-for-character the example [STYLE.md](STYLE.md) shows for
"name the fix, not just the fault" — the two documents were diffed by execution,
not by eye.

**What the empirical half found.** Syncing the reference surfaced a live bug that
document review had missed, which is the half's whole justification: Go Chat's
session sweeper ran `every(ctx, 5*time.Minute, …)` with **no call before the
loop**, so a reference app redeployed more often than five minutes never swept a
single expired row. The run-once now lives inside `every`, where both workers get
it. The reference was also still on the two-case `unknown` reader as its asset
cache-buster — the precise defect item 1 describes, shipped.

**Item 9's delegation was re-confirmed against the `claude-api` skill**, which is
what the run's own note asked for. All five paraphrased facts hold: refusal is an HTTP 200 whose
content is empty *or partial*; check the stop reason before reading content;
thinking-off can push reasoning into the visible answer, and adaptive-on at low
effort is both the fix and the cheaper request; "do not think" makes leakage
worse and naming the tags is measurably weaker than a generic instruction; and
the fallback header and parameter shape are a matched pair that 400s when mixed.
A grep for a drifted model ID, header, or limit found none.

**One reference feature closed five items at once.** Items 2, 4, 5, 6 and 9 had
no path through Go Chat: no handler waited on another system, no operation had a
step it could lose, no setting had a second half, and there was no AI capability
at all. Go Chat now has an assistant you mention in a room, and it reaches all
five — the port, the prompt in `domain`, `Alternating`, the refusal sentinel and
the wire-contract test (9); persist-the-message-then-reply, with a test per
failure proving the message still posts (4); `-assistant=anthropic` and its
credential validated as a pair, in both directions (6); a 10 s handler budget
under a 15 s client timeout under a 30 s `WriteTimeout` (2); and an adapter
built at boot that sends nothing until somebody asks it something (5).

Writing it was also the empirical half earning its place a second time. Building
the paired-setting check broke the smoke suite's own boot, because a stray
credential in a shared directory now stops the app — which is the rule working:
a key sitting unused beside `-assistant=echo` is a deployment that thinks it is
talking to a model and is not.

**Since v3.4.0 — patterns extracted from the JARVIS orchestrator (2026-08-17).**
Nine changes across seventeen documents, all sourced from one real project rather
than from review:

1. **[patterns/go-performance.md](patterns/go-performance.md) — the asset
   version buster.** This one is a **defect fix, not an addition**: the corpus
   mandated `immutable` static assets *and* pointed at a version reader that
   answers a constant (`unknown`, or a repeated `+dirty`) for any build from an
   edited tree. Together those pin a stale stylesheet in a developer's browser
   with no reload able to shift it. Replaced with a three-case reader.
   [patterns/go-cli.md](patterns/go-cli.md) and
   [operations/web-application.md](operations/web-application.md) now say which
   reader answers which question.
2. **[patterns/go-http-server.md](patterns/go-http-server.md) — the timeout
   ladder.** The corpus mandated timeouts at each layer and never ordered them.
3. **[patterns/go-http-server.md](patterns/go-http-server.md) — periodic work
   runs once before the first tick**, and `context.Canceled` at shutdown is not
   an error.
4. **[patterns/go-errors-logging.md](patterns/go-errors-logging.md) — required
   steps and enhancement steps**, and the ordering that makes degrading possible.
5. **[patterns/go-http-client.md](patterns/go-http-client.md) — boot does not
   wait on a dependency.** Lazy, cached lookups instead of startup probes.
6. **[patterns/go-config.md](patterns/go-config.md) rule 7 — paired settings are
   validated as a pair**, plus the long-value-in-a-file convention.
7. **[STYLE.md](STYLE.md) — error messages**, which the document did not cover
   at all. Name the fix, not just the fault.

8. **[patterns/htmx-server-rendering.md](patterns/htmx-server-rendering.md) —
   one discriminator, one definition.** The fragment test becomes a named
   function, `isFragment`, instead of the header pair written out in two places.

**9. [patterns/go-llm-adapter.md](patterns/go-llm-adapter.md) — a new document
(2026-08-17).** Written on the decision that AI capability is the default in
every service from here on, not an occasional integration — so the shape gets
written down once rather than re-derived per project. It layers on
[patterns/go-ports-adapters.md](patterns/go-ports-adapters.md): the prompt and
the conversation shape live in `domain` so two adapters cannot drift, a refusal
is a sentinel checked *before* the response text is read, the visible answer can
leak the model's own reasoning (from both directions — thinking off on a
frontier model, thinking on in a local one), and the degenerate adapter that
lets the app start with an empty environment is a product mode in `internal/`
rather than the fake in `_test.go`.

**Its load-bearing rule is a refusal to own facts.** Model IDs, request fields,
beta headers, and pricing are explicitly out of scope for the document *and* for
[VERSIONS.md](VERSIONS.md); the `claude-api` skill owns them and is updated with
the API, while this corpus is verified every ninety days. A pin here would be a
stale answer wearing this repository's authority. Wired into both the
web-application and cli-tool project types and checklists.

**The delegation was checked, and it holds.** A grep across the whole corpus for
a model ID, a beta header, a request field, or a token limit returns only
references to the skill's *name* — nothing on the wire has drifted into these
documents. Held against the `claude-api` skill, all five paraphrased facts stand
(listed under *the empirical half* above), including the counter-intuitive one:
telling a model not to think makes the leak worse.

Each change has a matching box in
[checklists/web-application.md](checklists/web-application.md), and the AI token
ceiling now has one in [checklists/cli-tool.md](checklists/cli-tool.md) too —
enforcement and verification both in place.

**Where the run attacked first, it was right to.** All three predictions paid:

- **Item 1 left a dangling claim**, exactly as expected — but in
  [checklists/web-application.md](checklists/web-application.md) rather than in a
  document, a `/healthz` box still reading "not `unknown`" after the item had
  established the canonical reader cannot answer `unknown`. The `+dirty` and
  `(devel)` shapes were then produced by a real toolchain rather than argued
  from this text; both hold.
- **Item 2's waiver did not bite hard enough.** The section blessed a
  `WriteTimeout` above the canonical 30 s and then used a 90 s budget in its own
  example — under the shipped 30 s socket *and* the shipped 10 s client timeout.
  Two defects, both fixed above.
- **Item 5's collision was not one.** [patterns/go-config.md](patterns/go-config.md)
  rule 1, *Boot does not wait on a dependency*, and
  [patterns/go-llm-adapter.md](patterns/go-llm-adapter.md) rule 15 agree: boot
  MUST NOT reach the model, MAY refuse over a local fact the requested mode
  needs, and an empty environment still starts, because the mode an empty
  environment selects is the degenerate one.

**Also since v3.4.0 — the checklists split their compound boxes (2026-08-17).**
This one comes from a review of the corpus rather than from a project. No rule
changed; the enforcement did. A box that named six conditions in one line — the AI
capability box was 556 characters — gets ticked while three of them fail, which
is the failure the checklist exists to prevent. Every box that needed two answers
is now two boxes. Counted against v3.4.0 — `git grep -c '^\s*- \[ \]'` — the
checklists go web-application 65 → 177, cli-tool 33 → 75, library 23 → 44. Only
library's number is the split alone; the other two also carry this run's new
boxes, so do not read them as a split ratio. Where several checks share a scope
or a document, the scope is a bold bullet and the checks nest under it, so an
ungrouped box can never read as part of the group above it. Each checklist states
the rule in its preamble ("One box, one check") so the next edit does not
re-compound them. The three
[`project-types/`](project-types/) pointers now say a box names its document *or
sits under a bullet that does*, and [SKILL.md](SKILL.md) is re-dated to
2026-08-17 after its protocol text was held against the current
[README.md](README.md) and found unchanged.

**Also since v3.4.0 — how a pattern leaves (2026-08-17).** [README.md](README.md)
gains *Retiring a pattern*, and it is the only change here that came from neither
a project nor a review: the corpus is at twenty-seven pattern documents with no
rule for subtraction, so every re-verification costs more than the last. Three
signals (subject gone, nothing reached it in a year, another document now says
the same thing), tier 1 exempt from all but the first, and a removal is a sweep
with the tombstone written into this file before the file is deleted. Nothing is
retired under it yet — the rule ships ahead of its first use on purpose, so the
first retirement is not also the argument about how to do one.

**The split lost nothing.** Every code span and every link target survived the
rewrite mechanically, and the handful of content words that changed are
rewordings rather than dropped conditions ("no cobra/viper/urfave" became "no
cobra, viper, or urfave"). Because a mechanical check cannot prove a condition
kept its *meaning* once it lost the sentence around it, the split boxes were then
read against their pattern documents one at a time — the timeout ladder (whose
"at or above it" had an antecedent the split had to name: the budget), the
required/enhancement ordering, and the session-cookie and machine-token groups,
which are safety tier. All five machine-token boxes and all four session-cookie
boxes match [patterns/go-auth-sessions.md](patterns/go-auth-sessions.md)
clause for clause. Only the checklists, the three project-type pointers, and
`SKILL.md` were touched; the `Last verified:` date on
[checklists/library.md](checklists/library.md) stays at 2026-08-15, because
restructuring a document is not re-verifying it.

**Empirical half: closed, before the tag.** Reference synced and tagged v3.5.0,
its `SPEC.md` pinning this release's commit. `./verify.sh` exits 0 against it:
every mechanical gate (gofmt, vet, staticcheck, govulncheck, tidy, race tests,
the vendored htmx checksum, static builds of both binaries), the adapter's
dependency direction proved by `go list -deps ./internal/anthropic`, the system
prompt asserted to live in `internal/domain`, the paired setting refused in
**both** directions with an error naming the file to write, and then the booted
binaries through the full smoke suite — including the new one: the assistant
answers a mention and stays out of a message that does not mention it, with no
key, no model, and no second machine, because `-assistant=echo` is the default.

**Correction (2026-08-17): the tag carried a tenth change this entry never named.**
[patterns/local-https.md](patterns/local-https.md) — a new 204-line pattern, commit
`65a6018` — landed between the v3.4.0 and v3.5.0 tags, so v3.5.0 shipped it and the
entry above lists nine changes. It reached no [`project-types/`](project-types/)
trigger table and no [`checklists/`](checklists/) box either, so the only ways in were
this repository's file tree, the tier-3 list in [README.md](README.md), and one
cross-link from [patterns/pwa.md](patterns/pwa.md). An agent walking the protocol
top-down never met it unless it was building a PWA — and the document argues that
install is the one feature here nobody can check before it ships without it.

**The bookkeeping defect this run did catch is why the tenth stayed hidden.** The run
found "a change count of eight against nine listed changes" and fixed the count. That
audit held the list against itself, so a change that never joined the list could not
fail it. **Mechanical check for every run from here: `git diff --stat <last tag>..HEAD`
is the list of changed documents, and the entry is written against that diff rather
than against memory of what the release was about.** One command would have caught
this.

The wiring landed 2026-08-17 in v3.5.1, recorded above.

### Earlier runs

Compressed to what a future reader still needs: the counts, and the findings that would
otherwise be re-litigated. The full narratives are in this file's git history.

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


## Where the numbers come from

`VERSIONS.md` carries its own dated source list. Re-verify against those links,
never against memory or training data — and never against a search result that
does not name a version.
