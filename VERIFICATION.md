# Verification Record

**Last verified: 2026-08-16**

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

## Run log

Newest first.

### 2026-08-16 — a word list for every project (v3.4.0)

The release that added [patterns/glossary.md](patterns/glossary.md): an optional
root `GLOSSARY.md` holding one entry per concept a project owns, and the words it
turned down. Tier 3 — a project whose vocabulary is the baseline's plus plain
English writes nothing down.

**Thirty defects in the changed documents, over ten adversarial passes** — the
last two clean, which is what the gate asks for. A new document takes more passes
than an edited one, and this one had to be held against itself: it prescribes a
format, so every rule it states is a rule its own worked example must pass. The
four worth remembering:

1. **The document's rule excluded an entry its own example contained.** Rule 3
   first said a glossary lists what the project *invented* — but the example's
   *Slug* is a web term everywhere. The criterion was wrong, not the entry. What
   earns a word its place is the project giving a general term a specific job:
   *which* of a room's two names goes in the URL is Go Chat's decision.
2. **`Label` collided inside its own project.** The example defined *Label* as
   the note on a machine token, in an application where every form control has an
   HTML label. It ships as *Token label* — the exact ambiguity this pattern
   exists to kill, found sitting in the pattern's own example.
3. **The checklist box asked for something no project can do.** It read
   "`git grep` for each *Avoid* word finds nothing", but `channel` hits every Go
   `chan` and `label` every `<label>`. The check is concept-scoped now, and it
   carries rule 5's exception for a rejected word that survives where renaming is
   expensive.
4. **Two conflicts with [STYLE.md](STYLE.md) went undeclared.** A word list has
   no runnable example for its first screen, and the cluster headings of rule 4
   are the category headings STYLE bans. `design-system.md` had to declare the
   same kind of exception for `DESIGN.md`; this document now declares both.

**Writing the reference's own glossary found two more, which is what the sync is
for.** Both came from checking the words against real code rather than imagining
them:

- **An *Avoid* word was one the project uses correctly.** *Author* first listed
  *sender* as a runner-up to ban. The reference pairs *reader* and *sender* on
  purpose — the person polling against the person who just pressed Send — so
  banning *sender* would have renamed a role the live-update design needs.
- **A seventh term, and an ordering rule.** Go Chat has an *invite code* the
  first draft missed, and seven entries in domain order read as a list to study
  rather than a file to look words up in. Rule 4 now says alphabetical.

One thing was deliberately left alone: the same act is `/register` in the routes,
"Make an account" on the button, and `signUp` in the tests. That is not glossary
drift — rule 2 scopes entries to nouns, and UI copy phrases an action for people.

**Empirical half: closed, before the tag.** Reference synced and tagged v3.4.0,
its `SPEC.md` pinning this release's commit, and its `GLOSSARY.md` is the file
this pattern quotes — diffed character for character, not eyeballed.
`./verify.sh` exits 0 against the commit that carries this entry: every
mechanical gate, the vendored htmx checksum, static builds of both binaries, then
the booted binaries through the full smoke suite.

### 2026-08-15 — a full re-review, and two claims that measurement killed (v3.3.1)

A sweep of the whole corpus, run against the toolchain rather than read. Five
rounds; the last two found nothing. **Three defects, and the two that matter are
both cases of this file being wrong about its own evidence.**

1. **The `Secure` session cookie was never actually fixed here.** The v3.2.0
   entry below records the finding and says the reference ties the flag to
   `ENV` — and `patterns/go-auth-sessions.md` still set
   `sessions.Cookie.Secure = true` flat. Only the reference was changed, so the
   corpus and its own executable check disagreed for a release, while the
   reference's README listed the finding under *Fed back into the baseline*.
   The rule now lives in the baseline, with the checklist and the project-type
   document carrying the same nuance.
2. **The `responseHandling` warning named an edit that is not dangerous.** Both
   `patterns/htmx-live-updates.md` and the v3.2.0 entry claimed that narrowing
   `{"code":"[23]..","swap":true}` to `2..` leaves polls running forever.
   `2..` still matches `286` — the poll still stops. Running htmx 2.0.10's own
   matcher (`new RegExp(code).test(status)`, first match wins, unanchored) over
   every plausible tidying edit found the real ones, now a table in that
   document: replacing the `[23]..` catch-all with the codes the app returns
   breaks 286, and **grouping `422` after `[45]..` silently kills the entire
   form-validation flow** — which nothing in the corpus had warned about.
3. **Both claims about the cookie overstated the damage,** including the one
   written during this run. Measured instead of reasoned: `curl` stores and
   returns a `Secure` cookie over `http://localhost` and `http://127.0.0.1`, and
   refuses to store it at all over a LAN address. Loopback is a secure context,
   so the flat flag works on a laptop and on `verify.sh` — it fails on a phone
   testing the mobile-first layout, on a container reached by hostname, and on a
   plain-HTTP staging box. The rule stands; only its stated reason was wrong.

**The mechanical layer was re-run, not re-read.** Every canonical Go snippet was
compiled, vetted, `staticcheck`ed, and executed against Go 1.26.6: the `run()`
skeleton and its test, `parseConfig` (including the empty-environment case rule 3
promises), the middleware chain, `OpsHandler`, the render helper, the forms
handler, the poll handler, `NewToken`, `clientIP`, and the whole `go-http-client`
retry path (its 503 test asserts two attempts). `openDB` was run against a real
database: WAL, `busy_timeout=5000`, `synchronous=1`, `foreign_keys=1` all read
back from a pooled connection, and `VACUUM INTO ?` wrote a snapshot. The
canonical `Makefile` ran end to end under macOS's GNU Make 3.81, `.env` present
and absent; the release workflow's cross-compile loop built all six targets under
`bash -e`. `fs.Sub` + `FileServerFS` was proven to need no `StripPrefix`, with
both `mime` registrations taking effect. Every version stamp claim was checked by
building tagged, dirty, untagged, and `-buildvcs=false` binaries — all four
report exactly what the corpus says. Contrast floors recomputed from oklch
(≥ 6.6:1 text, ≥ 3.2:1 border, ≥ 7.4:1 button), both manifest hex values
reproduced, the eight icon data URIs parsed as SVG, the `htmx-config` and
manifest JSON parsed, `DESIGN.md`'s seventeen values diffed character-for-character
against the tokens layer, and every pin re-checked upstream (Go 1.26.6, htmx
2.0.10 latest 2.x, `checkout@v7`, `setup-go@v7`, scs v2.9.0).

**Empirical half: closed.** Reference at `8341d4e`; `./verify.sh` exits 0 — every
mechanical gate, then both booted binaries through registration, session flags,
token renewal, rate limiting, the plain-form and htmx flows, the poll's 204 and
200 answers, the 422 contract, machine tokens, CSRF, the backup snapshot,
restart, and graceful shutdown. Run twice, before and after these corrections.
The reference already satisfied both corrected rules — `Secure` follows `ENV` in
its `main.go`, and its layout carries the canonical `responseHandling` order —
which is the whole reason defect 1 could hide: nothing that runs disagreed with
the corpus, only the corpus disagreed with itself. Its `SPEC.md` pin and its own
tag move to this release's commit when the tag is cut (gate items 2 and 3).

**A note this file owes its own readers.** v3.3.0 was tagged without an entry
here, which is gate item 4 — so the gate was broken by the release right after
the one that introduced it. The entry above covers both releases.

### 2026-08-15 — live updates, machine tokens, and a second binary (v3.2.0)

The release that came out of replacing the reference application. The todo app
had closed every rule it could reach; the holes it named — outbound HTTP, the
adapter half of ports & adapters, sessions, flash, secrets, backups, bottom
navigation, `<dialog>` — all needed a product with more in it. **Go Chat**, a
chat application with a command-line client, is that product, and it gave
`project-types/cli-tool.md` its first reference implementation as well.

**One gap found before any code was written.** The corpus had no rule for
keeping a page current: no polling, no SSE, no WebSockets, nothing. A chat
application cannot be built without answering that, and the answer is
constrained by "htmx is the only script tag".
[patterns/htmx-live-updates.md](patterns/htmx-live-updates.md) is the answer —
polling with a server-held cursor, a 204 for the quiet case, and the reasoning
for why SSE is not in this baseline yet.

**Thirteen defects in the changed documents, over eight adversarial passes** —
the last two clean, which is what the gate asks for. A new document takes more
passes than an edited one; the count is recorded rather than rounded down
because it is the honest cost of adding one. The ones worth remembering:

1. The new document's canonical handler called `a.clientError(w, status)`. Every
   other document in the corpus — and `go-errors-logging.md`, which defines it —
   uses `clientError(w, r, status)`. The snippet would not have compiled in any
   project built from this baseline.
2. The same handler passed a bare `[]Message` as its template data, which cannot
   render the sentinel the document's own markup shows: the sentinel carries a
   URL, so it needs the room and the cursor too. It also skipped `Vary` on the
   204 path, which `htmx-server-rendering.md` requires of every response that
   bypasses the render helper.
3. `checklists/web-application.md` contradicted itself: "Requests >100ms show an
   indicator" one line above "the poll carries no indicator". Both boxes now
   name the exception.
4. A sentence warning against narrowing the `responseHandling` pattern parsed as
   an instruction to narrow it — the opposite of its point.
5. `patterns/go-cli.md`'s new snippet put a `:=` statement and a package-level
   function in one block, which cannot be pasted as written and never says the
   two halves live in different scopes.
6. The same environment variable was `$TOOL_TOKEN` in two documents and
   `$MYTOOL_TOKEN` in the one that sets the convention.
7. `project-types/cli-tool.md` still said "Reference implementation: None yet",
   and this repository's README still described the previous run as current.

The rest were cross-references a new rule had made stale, an ambiguous name, and
a colon left dangling by an earlier fix.

**Two older defects, found by doing the work rather than by reading.**
`go-ports-adapters.md` had been missing from the README's file tree since it
shipped in v2.1.0, and it had **no checklist box in any checklist** — so a
pattern nothing enforced. That is exactly why the todo app could carry the
adapter half unexercised with every gate green. Both are fixed here, and the
tree is now checked against the real directories mechanically.

**Empirical half: two findings only a running application produces.**

- **A `Secure` session cookie cannot be exercised over the HTTP this baseline
  mandates.** `go-auth-sessions.md` set the flag unconditionally;
  `project-types/web-application.md` says the binary only ever speaks plain HTTP
  behind a TLS proxy. The reference ties the flag to `ENV`, which the deployment
  sets and which is the thing that knows whether TLS is in front. (This entry
  originally said the pair makes an app nobody can sign in to in development and
  an acceptance test that cannot reach an authenticated route. Both overstate
  it — loopback is a secure context, so the flat flag survives `localhost`. The
  2026-08-15 entry above measures what actually breaks, and the rule stands for
  that reason.)
- **htmx stops polling on 286 only while `responseHandling` counts 286 as a
  swap.** Traced through the vendored htmx 2.0.10: the cancel sits inside the
  swap branch (`if (shouldSwap) { if (status === 286) cancelPolling(elt) }`), so
  the canonical `htmx-config` meta works through its `{"code":"[23]..","swap":true}`
  rule rather than by design. Both codes are now documented as load-bearing.
  (The example this entry originally gave for a breaking edit was wrong — see
  the 2026-08-15 entry above, which corrects it.)

**Every changed snippet was compiled and run,** not read: the polling handler,
`NewToken`, and the CLI's `token` reader, through `gofmt`, `go vet`,
`staticcheck`, and `go run` against Go 1.26.6. `NewToken` was checked by its
output — a 43-character secret from 32 random bytes, a 64-character hex hash.
The claim that `http.CrossOriginProtection` admits non-browser clients is
verified by execution rather than by reading: the reference's CLI posts messages
through that middleware in `verify.sh`.

**Empirical half: closed.** The reference implements the whole corpus end to end
and `./verify.sh` exits 0 — every mechanical gate, the vendored htmx checksum,
the CSS gates, static builds of both binaries, the adapter's dependency
direction, then the booted binaries smoke-tested through registration behind a
credential-file invite code, session cookie flags, token renewal, rate limiting,
the plain-form and htmx flows, the poll's 204 and 200 answers, escaping, the 422
contract, machine tokens end to end, CSRF, the backup snapshot, restart, graceful
shutdown, and the `chat` client talking to all of it.

### 2026-08-15 — governance: the gate, the tiers, the staleness switch (v3.1.0)

The release that added this file. It changed no rule the reference implements — no
`patterns/`, `stack/`, or `operations/` document was touched — so the empirical half
tested the new obligations rather than new mechanics.

**One defect, found by the sync itself, which is the point.** The waiver format first
mandated the heading `## Waived baseline rules`. The reference's section holds waivers
*and* conformance notes side by side, so adopting that heading would have relabelled
"this app needs no backups" as a waived rule — the opposite of what it says. The rule
now requires the six fields and lets the heading fit the list. **The first release
under the gate found a defect in the gate's own release.**

Applying the format to the reference also surfaced what the format is for: five real
waivers there had a rule, a reason, and a containment note, but **no date and no
decider** — recoverable only from `git log -S`. They now read `waived 2026-08-10 by
Andy` and so on, and three bullets that were never waivers (no backups, no outbound
HTTP, the partial type scale) say plainly which they are.

**Empirical half: closed, before the tag.** Reference synced and tagged v3.1.0, its
`SPEC.md` pinning this release's commit. `./verify.sh` passed every gate — mechanical
checks, vendored htmx checksum, static build, then the booted-binary smoke tests. Run
on 2026-08-15 against the commit that carries this entry.

### 2026-08-15 — the operations split (v3.0.0, stamp fixed in v3.0.1)

The change that moved servers, containers, and their versions out to
`baseline-ops` and left this repository the deployment contract.

**Sixteen defects fixed across twelve documents.** The two that mattered:

- The split dropped the fact that `X-Forwarded-For` arrives holding **one
  address, not a chain**. That is a code-affecting fact with a live consumer —
  the per-IP rate limiter — and there was no fallback to `RemoteAddr` for the
  no-proxy case, so every visitor keyed on `""`.
- `VACUUM INTO` still named a systemd `StateDirectory` path. A relative path
  would not have reached it anyway: `VACUUM INTO` resolves against the process's
  working directory, not the database's. The replacement `VACUUM INTO ?` snippet
  was **verified by running it** — bound parameter, `modernc.org/sqlite`, Go
  1.26.6, `gofmt` and `go vet` clean.

The rest were stale references to the removed products (`journal`, "owns the
topology"); a `deployment uses a container image` claim in the file that had
just said this repository describes no deployment; `HTTPS everywhere` left
standing over a binary that only speaks plain HTTP; and a missing `HOST`
obligation that leaves a containerised app silently unreachable on loopback.
Every relative link, every cross-document `rule N` reference, and every file
tree's alphabetical order were re-checked mechanically. Two further passes over
the corrected corpus found nothing.

**The lesson, recorded because it will recur: an extraction drops facts its
consumers still need.** Sweep every consumer after moving anything out.

**Empirical half: closed, but late.** The reference was synced to v3.0.1
(`8ae29b9`), its `SPEC.md` pins baseline `6f8750e`, and `./verify.sh` passed
every gate — mechanical checks, vendored htmx checksum, static build, then the
booted-binary smoke tests (CSP header, manifest MIME, plain-form and htmx flows,
422 on invalid input, CSRF rejection, state surviving restart, graceful
shutdown). This finished **after** the tag rather than before it. The tag gate
above is the fix.

### 2026-08-15 — full-corpus sweep (v2.0.1)

**Seven defects fixed across eight documents:**

- A two-pool SQLite snippet that does not compile and drops both mandatory error
  checks.
- A bottom-navigation rule that told readers to delete a grid row the fixed bar
  never vacated — `position: fixed` sits on `footer nav`, so `<footer>` stays a
  grid item.
- htmx's history cache named as `sessionStorage` when it is `localStorage`,
  which outlives the tab and the browser rather than the session.
- A `primary` palette described as required by the `design.md` spec, which in
  fact only warns and lets tools invent one.
- A `debug.ReadBuildInfo` one-liner that discarded the `ok` result it needs to
  check.
- Two list recipes whose `list-style: none` silently strips list semantics in
  Safari.
- A field error tied to its control for the eye only.

**The mechanical layer was re-verified by running it, not by reading it.** Every
pinned version was checked against upstream; the contrast floors and both
manifest hex values came out exactly as written. Two further passes found
nothing.

**Empirical half: missing.** The reference was not re-synced in this run. Fixes
here are verified against the toolchain and upstream sources, not against a
building application.

### Earlier runs

- **2026-08-14** — re-review of the v1.14.0 additions (security-headers,
  go-http-client, go-config). 4 defects. The one worth remembering: a retry that
  sends an empty body on the second attempt.
- **2026-08-13** — css-typography and css-icons. 7 rounds, 29 defects,
  converged.

## Where the numbers come from

`VERSIONS.md` carries its own dated source list. Re-verify against those links,
never against memory or training data — and never against a search result that
does not name a version.
