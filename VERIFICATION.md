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
   as *Grading a finding* below defines the two. **A pass reads whole, as it stands
   after the last fix, every document changed since the last tag and everything
   *Owed* lists under *Unread, or read and never passed*.** A read of less — a diff,
   or only the documents the last pass failed — is a check: it can find a defect,
   and it counts for nothing here. Two reviewers on one text at one time are one
   pass. Reading is not
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
stands for the whole rule it points at, in its own words or through its section's lead
line, and a tier-1 rule no box checks is graded as if nobody checked it.

**The reviewer grades,** and whoever fixes does not regrade; a finding is withdrawn
only on evidence that it is wrong. Two grades for one finding: the higher holds. A
finding in the reference is the reference's, and is listed under *The reference, behind
this corpus*. A claim nobody could check is not a finding: it is listed under *Owed* as
unchecked.

**Maintainer text is graded by what a release may then ship.** That is this file, and
the README outside *Which rules can be waived* and *The task brief*, which projects
read. It is medium when, followed to the letter, it lets a tag carry what the gate means
to hold, holds what the gate means to pass, or loses a debt; low when every reading
ships the same thing.

**Evidence, or it is not a finding.** The command and its output, or the source and
the sentence that contradicts the claim.

**A low never holds a tag.** It is fixed in the run or listed under *Owed*. A fix made
after the last pass is unread: *Owed* names its commit, and the next run reads it.
Such a fix changes wording and nothing else. One that changes what a rule requires, a
snippet, a recipe, or any statement of a tier-1 rule — the rule, its header, its
README entry, its box — is a new change: the count of passes starts again, or the low
stays listed.

## The tag gate

**No tag ships until the first four are true, and no release is finished until the
fifth is.** This is a gate, not a goal, and it has no override.

1. Two consecutive adversarial passes find nothing high and nothing medium, and in
   each of them the build from the documents alone is green. The passes read the
   changed documents and everything *Owed* lists as unread. `make structure` and
   `make tokens` exit 0, or the budget's waiver is on the record.
2. The reference implementation is synced to the change, *The reference, behind this
   corpus* below is empty, and `./verify.sh` exits 0 against the baseline commit its
   `SPEC.md` pins.
3. The reference's `SPEC.md` pins that commit and carries the four-field brief, and
   its own tag mirrors the baseline version.
4. **Nothing a project reads changed between the pinned commit and the tag.**
   `git diff --name-only <pin> <tag>` names this file and nothing else.
5. After the tag, its release page records the run, naming the reference release and
   the `verify.sh` result.

**A change that alters no rule, snippet or recipe skips the build:** a typo, a link
that moved, a pin. Condition 2 is its build.

**One change does not wait for *Owed*: a pin whose note names a security fix.** That
pin is tier 1, so it ships alone — the `VERSIONS.md` row and the places that pin sits,
nothing else — on a run over that diff. That run neither reads nor clears *Owed*. A
pin that cannot go green without changing a rule ships with that rule and nothing else,
on a run over that diff.

**Condition 1 asked for zero defects until 2026-11-09, and six releases in a row
shipped without it.** v4.8.0 through v5.2.0 each went out on Andy's decision, each
recorded. On every change larger than a pin the count never reached zero: v5.2.0's
sixteen passes found 16, 14, 16, 11, 12, 12, 9, 9, 6, 6, 5, 6, 6, 9, 6 and 9, and a
count that adds a leak to a misplaced comma does not say when to stop. The condition
now counts only what a project would get wrong. **That is a different bar, not a
lower one.** v5.1.0 ended on one round with nothing high or medium, which is one pass.
v5.2.0's last two passes still fail it: pass 15 on two documents that answered one
question differently, pass 16 on a socket that kept a private room's state. Seven
builds from the documents alone, in passes 10 to 16, every one a web application, were
green through both, so the build is a floor and not the proof. Andy decided the bar on
2026-11-09: high and medium, and a build. The sentences are Claude's; the ones that
changed what ships after that day are listed under *Decisions left to Andy*.

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

**This section says what the next run faces.** Its first pass checks this section
against the last run's commit bodies and the last release page before it reads anything
else: the section is written after a run's last pass, so nobody has read it. Then it
reads everything under *Unread, or read and never passed*. An entry leaves that list
when a whole read of it, as it stands, finds nothing high or medium. Listing a finding
under *Known, not fixed* does not waive it: a pass that reads its document finds it
again, and a high or a medium then holds the tag. An entry with no grade is a decision
or a note.

**While anything is listed under *Unread, or read and never passed*, no new pattern
lands** ([README.md](README.md) *Maintenance protocol*). A wording fix listed there does
not count.

### Unread, or read and never passed

The 2026-11-10 run read whole, twice, the documents its first pass changed. Neither read
was a pass as this file defines one: no library was built, and what the run changed in
other documents was read where it changed. The first nine entries each had a high or a
medium in the second read. Each is fixed, and no pass has read the fix. A third, narrow
look at the fixes ran; it is a check, and counts for nothing here. It found two highs and
eighteen mediums in them. Those are fixed in `52fc2e4`, `643225f`, `768e460`, `563a9b1`
and `cfa7bf6`, which reach every entry below but the WebAssembly client's, and which
nobody has read at all.

- **`patterns/go-auth-sessions.md`, whole,** with its boxes. Rewritten on 2026-11-10,
  and the second read found four highs in the rewrite (`a04de9c`, `eb27c42`).
- **`patterns/wasm-client.md`, whole,** with *Re-resolving a long-lived connection*. New
  in v5.2.0; eighteen reads, none passed. `patterns/go-authorization.md` rule 6 came
  back clean.
- **`patterns/go-email.md`, whole.** Six reads, a medium in each. Its date did not move.
- **`patterns/go-sqlite.md`, `patterns/go-file-uploads.md`, and in
  `patterns/go-data-deletion.md` rule 6,** a prohibition since `2a21420`, its header, the
  two sentences `bd65def` added to *Testing*, and the password counter in its lookup
  snippet and in the account's `DELETE`, added after the narrow look (`563a9b1`,
  `39ad142`).
- **`patterns/go-http-client.md`, `patterns/go-config.md`,
  `patterns/go-errors-logging.md` and `patterns/go-forms-validation.md`** (`09561c4`,
  `7793d93`, `eb27c42`).
- **`stack/htmx.md` and `patterns/htmx-server-rendering.md`** (`9db3dcc`, `7793d93`).
- **The three checklists and the README's tier-1 list,** as `a2abc66` restructured them
  and `03bb4c3` corrected them.
- **Changes made after a whole read that found nothing high or medium:** in
  `patterns/security-headers.md` the test, the paragraph under it and the `form-action`
  row (`7793d93`, `03bb4c3`); and the header of `patterns/htmx-live-updates.md`, which
  names a tier-1 rule since `9db3dcc`.
- **Two snippet lines of `patterns/go-ports-adapters.md`** (`09561c4`). The run did not
  read that document whole.
- **This file's *What a review run is*, *Grading a finding*, *The tag gate* and *Owed*,
  and the README paragraphs that go with them.** Four reviews read earlier versions and
  found 14, 16, 9 and 8 mediums. What the fourth found in the gate itself is under
  *Decisions left to Andy*, and nobody has read the text since.
- **Wording fixed after a whole read that found nothing high or medium:** `stack/html.md`
  and `stack/go.md` in `03bb4c3`, `patterns/go-http-server.md` and `operations/ci.md` in
  `0f20f36`.

### Known, not fixed

- **Retired on 2026-11-10, on Andy's call:** `patterns/go-child-process.md`, and
  `patterns/go-cli.md` *A tool that listens* with the clause of 2026-10-09 that let a CLI
  serve the person who started it. Neither ever passed a read: eight for the first, four
  in one day for the second. Their one live user is baton, which keeps its code and
  records both as its own deviations. The rule that a secret never travels on a child's
  command line moved to `patterns/go-cli.md` *Config precedence*. The text as it last
  stood is at `39ad142`.
- **Medium — two boxes of `checklists/cli-tool.md` are marked tier 1 with no rule behind
  the mark:** partial work being safe, and `-force` for a destructive action.
  `patterns/go-cli.md` and the README's list name neither. A decision, below.
- **Medium — tier-1 rules that no box checks:** a child's secret, in
  `checklists/web-application.md` (2026-10-04); and the patch a security pin sets, in
  any checklist. `operations/ci.md` owns that rule now. `govulncheck` fails below
  the current pin only where the code reaches the fixed symbol: a server with no
  outbound client passes under Go 1.27.2 (run, 2026-11-10).
- **Medium — no document rules a URL a user supplies.** A webhook sent through the
  canonical client reached the ops listener and its profiles, followed a redirect with
  its secret, and its "delivered" was an oracle for what the machine can reach (the
  2026-11-10 build). A decision, below.
- **Medium — no rule covers changing the address a reset link is mailed to.** In the
  reference a session alone sets it, and the reset then hands over the password: a
  stolen session becomes the account (the reference's sync, 2026-11-10).
- **Medium — a secret a user typed, which the application must send later, is stored as
  typed.** No document says how it is held; a snapshot holds it in the clear.
- **Medium — a deleted row's bytes stay in the database file,** and a sent outbox row's
  body with them: `secure_delete` is off under the canonical DSN.
  `patterns/go-data-deletion.md` says so since 2026-11-10. A decision, below.
- **Medium — `patterns/go-file-uploads.md`: a urlencoded post to an upload route loses
  its 413 and its 400.** `ParseMultipartForm` returns `ErrNotMultipart` and drops the
  error its own `ParseForm` hit, so an over-cap or malformed body reads as an empty form
  and answers 422. A second `ParseForm` returns nil; calling it first finds both (run,
  Go 1.27.3). Nothing is stored either way.
- **Medium — over the upload cap, the htmx path shows the reader nothing.**
  `patterns/htmx-server-rendering.md` keeps every error but a 422 off the page, on
  purpose. A decision, below.
- **Medium — nothing says who may read the database file.** The driver creates it, its
  WAL and every snapshot world-readable; `operations/web-application.md` asks only for
  a writable directory.
- **Medium — `stack/htmx.md` asks every request over 100 ms for an indicator,** and its
  box checks that. No canonical snippet carries one, and on a boosted link or the
  *Show older* control nothing can: `.htmx-request` lands on the link itself (the
  2026-11-09 and 2026-11-10 builds).
- **Medium — `patterns/time-and-dates.md` bans `time.Local` everywhere.** A CLI runs on
  the reader's machine and has no other zone, and `checklists/cli-tool.md` has no
  section that sends a tool that prints a time to that document.
- **Medium — rules that meet the README's tier-1 test and that no document calls
  tier 1:** no `InsecureSkipVerify`; internal error text never reaching the browser;
  work that must not be lost being a table; the sent outbox row losing its body; the
  proxy's `X-Forwarded-For`, which the rate limit keys on; the rehearsed restore; and
  three written on 2026-11-10: the session janitor's hour, `no-store` on an owned file,
  which only a snippet's comment states, and the child's port being free before `Start`.
  And
  the headers of four tier-1 documents place only some of their rules:
  `go-authorization.md`, `go-file-uploads.md`, `go-data-deletion.md`,
  `security-headers.md` (2026-11-10).
- **Medium — a password reset leaves the user's machine tokens,** and a token minted
  from a stolen session outlives it (2026-11-10). A decision, below.
- **Medium — `patterns/go-config.md` makes `DATABASE_URL` a flag, an environment
  variable and a logged field.** A Postgres URL, which `project-types/web-application.md`
  allows, holds a password (2026-11-10).
- **Medium — the gates check none of the tier structure.** `make structure` and
  `make tokens` pass with a box pointing at a rule that does not exist, a mark on a
  tier-2 box, and a tier-1 section deleted (34 breaks tried, 2026-11-10).
- **Low, in `patterns/go-auth-sessions.md`:**
  - No schema for the sessions table is printed; `data IS NULL` is the only statement
    of what an emptied row is.
  - One rate-limit budget or one per route, and where password hashing sits, are
    unstated.
- **Low — `patterns/go-authorization.md`: in the second-mux shape, a route registered
  on the public mux under the mounted prefix is public, and nothing says so.** A
  decision, below.
- **Low, in `patterns/go-cli.md`:** *Logging* says a tool does not log, and a tool that
  listens must build a logger; the box "Nothing a user installs reads it" states a
  condition `stack/makefile.md` rule 6 does not.
- **Low, in `patterns/go-config.md`:** the canonical parser has no check for the log
  transport, which `patterns/go-email.md` makes tier 1, and describes `ENV` as the log
  format only;
  `readCredential` says nothing about a missing file; a
  non-string verb (`%d`) prints a `Secret`, which `go vet` catches only for a constant
  format.
- **Low, in `patterns/go-sqlite.md`:**
  - An empty database path is refused nowhere at the config edge.
  - A `..` through a symlink puts the snapshot elsewhere.
  - Windows paths: rule 10 reads paths the Unix way and goes no further.
  - The prune matches `app-*.db`, which a database named that way also is.
  - Two snapshot runs at once can leave a half-written file under the day's name.
  - The first open of a new file answered `database is locked` in 8 boots of 480, and
    in 29 when three reads raced the migration.
  - `openDB` is unexported, and three packages need it (the 2026-11-09 build).
- **Low, in the server documents:** an error from `net/http` or the JSON decoder can
  still quote a broken peer's header line, or a member name of its body, into
  `patterns/go-http-client.md`'s wraps; the security-headers test reads one GET of `/`,
  so a middleware that sends the policy on that request alone passes it; "above
  `ReadTimeout` + the budget" and "ceiling the
  budget at 20 s" do not say the same thing; `make run` leaves `app.db` unignored;
  `main.go` under about 100 lines does not fit two servers; a panic in a background job
  ends the process and the requests in flight with it, which
  `patterns/go-background-work.md` describes as losing the jobs.
- **Low, from the 2026-11-10 web build:** `wasm-opt`'s version is to be named and
  checked and has no `VERSIONS.md` row, and the `.build`, `.sum` and `make wasm`
  contract is prose only; raising `ReadTimeout` for an upload is prescribed in one
  document and a waiver in another, with no number; the cap-site line cannot name a
  route with an id, and the cap is the body's, not the file's; a comment in
  `patterns/go-background-work.md` says the errgroup cancels at `Wait`, and it cancels at
  the signal; "one test per enhancement failure" meets "never fake what you own" when
  the dependency is the store; `patterns/go-performance.md`'s middle case is not what a
  checkout build reaches.
- **Low, in the htmx documents:** `hx-post` and `action` escape a non-numeric id
  differently; the validator warns on `role="list"`; the `hx-confirm` box and
  `patterns/go-data-deletion.md` disagree; `patterns/css-typography.md` calls
  `text-wrap: balance` Baseline Newly, and it turns Widely on 2026-11-13.
- **Low, from the 2026-11-09 build and still standing:** `operations/web-application.md`
  says the binary is configured by exactly its list, and four patterns each need a knob
  outside it; `patterns/css-icons.md` asks for the Lucide notice and does not print it;
  `stack/go.md` asks for interfaces of one to three methods, and a store has more;
  `no-store` on authenticated pages (`patterns/go-performance.md`) has no box.
- **Low, left by the narrow look and the reference's sync:** "no row changed is a
  refusal" does not say what a rehash at sign-in refuses, and a reset that reads its
  link inside the writing transaction can never be refused by it; a `Commit` after the
  client left returns `sql.ErrTxDone`, which `serverError`'s exception does not cover, so
  that request logs an error and writes a 500 to nobody; the forms and server documents
  do not say which of `recoverPanic` and `serverError` renders the 500 page; an
  abandoned request is "answered with nothing", and its access-log line then shows a
  status nobody sent; Chrome keeps a `no-store` document in its back/forward cache until
  the session cookie changes, so a session ended on the server alone still shows an owned
  file on Back (2026-11-10).
- **Low — a serving tool's exit code after Ctrl-C.** `checklists/cli-tool.md` asks an
  interrupted run for non-zero; the canonical `serve` returns nil. A decision, below.
- **Low — dates older than the text under them.** `patterns/go-data-deletion.md` says
  2026-11-10 and its rule 6 was rewritten that afternoon; `patterns/security-headers.md`
  and `patterns/go-ports-adapters.md` say 2026-11-09 over the changes listed above. The
  README has no answer for a document changed after its date.
- **Low — checklist boxes that hold several checks,** against the README's *Writing a
  checklist*; and a tier-1 box whose subject a project lacks has no answer but
  `SKILL.md`'s full protocol.
- **Low — `govulncheck` reported GO-2026-5932** in `golang.org/x/crypto` v0.58.0 on
  2026-10-31 and again on 2026-11-10: no fix released, and not called.
- **Low — commit subjects.** `STYLE.md` asks for the imperative; most of this
  repository's subjects are noun phrases.
- **Low — what the builds from the documents had to invent:** twenty decisions on
  2026-11-09, twenty-nine for a CLI and the web application's own on 2026-11-10. They
  are in the bodies of `c0a6117` and of the commit that added this line.
- **Unchecked:** a recycled PID under the child process's deferred wait; the live-region
  markup under a screen reader; Firefox and Safari for the two things
  `patterns/go-cli.md` says of every browser, a handshake with no `Sec-Fetch-Site` and
  `none`; Firefox and Safari, for what Chrome showed about a form's redirect, a
  cached page's socket and an owned file after sign-out; Linux, for every terminal run
  of the child process; whether the proxy's log holds a reset link's query string.
- **Decisions left to Andy:**
  - **The gate gates a tag, and projects read `main`.** The installed copy is a symlink
    to this repository, so every rule of this run reached projects at its commit, read
    or not, and a security pin tagged on top of `main` would carry the whole unread
    branch. One sentence settles it either way: the installed branch is the last tag
    and a run stays on its own branch until the gate passes; or the gate says what an
    untagged commit may carry.
  - Whether the freeze covers a new rule in an old document. Today it stops a new
    pattern and nothing smaller, and this run added a section of tier-1 rules to
    `patterns/go-cli.md` under it.
  - What a decision does to a finding, and whether a medium under *Known* holds the tag
    by being listed. Today it holds only if a pass finds it again, and four listed
    mediums sit in no document a pass must read.
  - Which read takes an entry off *Unread*: one whole read of that entry, as the lead
    of this section says, or a pass.
  - The unit of "a run over that diff" for a security pin, which by this file's own
    definition of a pass counts for nothing.
  - The gate's sentences are Claude's. Three changed what ships after the 2026-11-09
    decision and were never confirmed: the freeze ends when *Unread* is empty, not when
    *Owed* is; a pin that cannot go green without a rule ships with that rule; a change
    that alters no rule skips the build.
  - Smaller questions about the gate's wording: nothing ties the next tag to the last
    release page; "wording" and "alters no rule" are two tests for one class, both
    applied by whoever fixes; `SKILL.md` and the README answer differently what an agent
    does with a rule that does not work, and `VERSIONS.md` and `SKILL.md` what it does
    past 90 days; this file calls any pin with a security note tier 1 where the README now
    says the Go pin.
  - A CLI may serve the person who started it (2026-10-09). The run answered the
    listener's defects with rules; taking the clause back out of the definition is the
    other fix.
  - The two CLI boxes above: name both rules tier 1 in `patterns/go-cli.md` and the
    README, or drop the marks.
  - Whether a password reset deletes the user's machine tokens. Today it does not.
  - A rule for a URL a user supplies: no redirect followed, and no dial to this
    machine, is what the build ended on. It needs room `patterns/go-http-client.md` and
    the web floor do not have.
  - Whether the canonical DSN carries `secure_delete(1)`, which is a fifth tier-1
    pragma in every project.
  - Whether an upload form may carry one `hx-status:413` line, or its label carries
    the cap.
  - Whether `patterns/go-authorization.md` keeps the second-mux shape.
  - Whether a tool that only serves exits 0 after Ctrl-C. `checklists/cli-tool.md` asks
    an interrupted run for non-zero; the canonical `serve` returns nil.
  - Whether a tool's `go.mod` says `go 1.27.3`, so that `go install` on an older 1.27
    cannot build it below the security floor.
  - The pass-1 rule changes, each open to a veto: no mutation on a GET and *Never log*
    as tier 1; the session token hashed in the store, a deleted session row kept empty,
    the limiter keyed on a /64; a password change asking for the current password; no
    bcrypt fallback; `"defaultSettleDelay":0`; a snapshot written to a temporary name;
    the client's `do` returning the response of a one-attempt request; a secret type
    that stops at `main`.
  - The pass-2 rule changes, each open to a veto: an adapter's error carries no body
    and no URL, so a CLI cannot say why a server refused (the reference's prints
    `refused: status 422`); a password write is guarded by a counter; registration by email answers
    a taken address like a free one; a machine token is created after the password is
    asked for; no migration drops a referenced table; the upload janitor's limits are
    tier 1 and an owned file is `no-store`; a tool that listens refuses a foreign
    `Origin` and forwards no `none` request; a tool that owns a child has no force-kill
    hatch.
  - The narrow look's rule changes, each open to a veto: every statement a password or
    a reset link allowed names the counter; a blob only for what fits the blanket 1 MiB
    cap; the upload janitor waits an hour; `INSERT OR REPLACE` is barred on a table a
    foreign key names; a `none` request goes to the tool's own handler.
  - The budgets. The web floor stands at 24,986 of 25,000, and `wasm-client.md`,
    `go-auth-sessions.md`, `go-data-deletion.md`, `go-file-uploads.md`, `go-http-client.md`
    and `go-config.md` within 11 of 3,800. The next rule on any of them needs a number
    moved or text cut.
  - Scroll-driven animations are Baseline Newly since 2026-10-27;
    `patterns/css-motion.md` still keeps them out.
  - `stack/css.md` exempts a `font-family` name from the feature rule, to keep
    `ui-monospace`. Dropping the name is the other fix.
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
- **Pins behind upstream on 2026-11-10:** htmx 4.0.1 is npm's `next` since 2026-11-01,
  and `modernc.org/sqlite` v1.62.0 shipped on 2026-11-07. `VERSIONS.md` pins 4.0.0 and
  v1.61.0. Go 1.27.3, scs v2.9.0 and TinyGo 0.44.0 are current.
- **Low — dates that did not move on 2026-11-10.** `32d4dd5` moved five. Five more were
  clean in the second read and kept theirs: `stack/html.md`, `stack/go.md`,
  `patterns/go-http-server.md` and `operations/ci.md` took a sentence afterwards, and
  `patterns/go-authorization.md` was read in two halves by two reviewers. No date has
  moved since v5.1.0 for `patterns/go-project-layout.md`,
  `project-types/web-application.md`, `operations/web-application.md`, `SKILL.md` and
  `VERSIONS.md`, read only where they changed, or for any document under *Unread*.

### The reference, behind this corpus

The reference follows `39ad142`, the last commit of the 2026-11-10 run that changes
anything a project reads: its `SPEC.md` pins that commit on the branch `sync-owed-run`,
and `./verify.sh` exits 0 against it (94 steps). One thing is behind, and condition 2
needs it settled before the tag that carries this run:

- **Attachments are blobs under a 3 MiB cap.** `patterns/go-file-uploads.md` keeps a
  blob for what fits the blanket 1 MiB cap since `768e460`. The reference's README lists
  it as not followed and not waived: lowering the cap, moving the bytes to a directory,
  or a waiver is a decision.

Found in the reference beside the rules it was held against, and not fixed there:
`gochat` validates its `-addr` at the first request, not when it parses, so a bad one
exits 1 where the checklist asks for 2; and its recovery address is the entry under
*Known* above.

The twelve entries the 2026-11-09 run listed here are settled on `sync-owed-run`.

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
