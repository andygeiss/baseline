# Verification Record

**Last verified: 2026-09-08**

How this repository proves it is right. The README states the standard in a
paragraph; this file holds the gate and the standing arguments behind it. What
each run found is on its tag's
[release page](https://github.com/andygeiss/baseline/releases); the run log that
lived here until v4.6.0 is in git history. It is written for whoever is about to
tag a release, or is auditing whether a rule was ever actually checked.

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

The two halves catch different bugs. Document review found a stale
`X-Forwarded-For` fact (v3.0.0); only a running application would have found a rule
that contradicts another one nothing points at.

## The tag gate

**No tag ships until the first four are true, and no release is finished until the
fifth is.** This is a gate, not a goal.

1. Two consecutive adversarial passes over the changed documents find zero defects.
2. The reference implementation is synced to the change, and `./verify.sh` exits
   0 against the baseline commit its `SPEC.md` pins.
3. The reference's `SPEC.md` pins that commit and carries the four-field brief, and
   its own tag mirrors the baseline version.
4. **Nothing a project reads changed between the pinned commit and the tag.**
   `git diff --name-only <pin> <tag>` names this file and nothing else.
5. After the tag, its release page records the run, naming the reference release and
   the `verify.sh` result.

**Conditions 2 and 4 were one sentence until 2026-08-18, and it was one no release
could meet.** It read "`./verify.sh` exits 0 against the exact baseline commit
being tagged" — but the run record then lived in this file and named the reference
commit, so the tagged commit could never be the one the reference pinned. The order
now: the rules commit, the reference synced and tagged against it, the *Owed* section
cleared, the tag, then the release page.

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

- **2026-10-04 — a child process the tool keeps running.** New
  `patterns/go-child-process.md`, tier 2 with its secret rule tier 1, and its trigger
  section in `checklists/cli-tool.md`. One project invented the shape — splash, a proxy
  that starts the inference engine it fronts — and Andy chose to extract it: the child in
  a process group of its own, one stop signal sent before the tool's own shutdown, the
  wait before the tool returns, SIGHUP unless `nohup` ignored it, and the test binary as
  the fake child. The first draft's stop path ran against the real engine for Ctrl-C,
  SIGHUP, and an engine that died. Review then rewrote it: the stop goes to the group, not
  the PID; SIGTTOU and SIGTSTP are ignored before the child starts, so it inherits both;
  the deferred wait polls the group, ending as soon as all of it has gone, and whatever
  outlasts a grace counted from that SIGTERM gets SIGKILL, a helper the child left behind
  included; an interrupted run exits non-zero; and the hatch ignores the second SIGHUP a
  closing zsh terminal sends. The tests gained a helper mode of their own, a fake that
  leaves its helper behind, a check that the deadline counts from the stop, bounded waits,
  and a `t.Cleanup` that kills the fake's group. The rewrite runs under a real pty, in zsh
  and bash, against a fake engine with a helper of its own. The tier-1 secret rule binds a
  program run to completion too; the CLI checklist checks it in its secret section. The
  web-application checklist gets no section, and no box for that secret rule either: the
  case arose in a CLI, and that checklist sits 18 tokens under its budget, its change
  path 37 — a gap for the budget decision the web path is already waiting on.
- **2026-10-09 — a CLI may serve the person who started it.** The child-process pattern's
  proxy contradicted `project-types/cli-tool.md`, which said a process that stays up to
  serve requests is not a CLI. Andy chose to widen the definition rather than narrow the
  pattern: a foreground tool that serves the person who started it until Ctrl-C, like a
  local proxy, is a CLI; one meant to stay up unattended, or to serve other people, is a
  web application. *A CLI terminates* now draws the same line. Left open: a CLI that
  listens on a port gets none of the web application's cross-origin rules, server
  timeouts, or request-body cap.
- **2026-10-10 — both back after v4.8.0, v4.8.1, v4.8.2 and v5.0.0, round five's
  findings still open.** `7355e4b` set them aside so the Go 1.27.2 security pin could ship
  without them, `6af59d2` did again for v4.8.1, `ebed591` for the Go 1.27.3 pin in
  v4.8.2, and `86e02cc` for htmx 4.0.0 in v5.0.0; they return as they left. Round five found
  ten defects in them, and none is fixed. Three are medium, all in
  the tests the pattern prescribes: none tells the polling wait from the single probe it
  replaced, or a deadline counted from the start from one counted from the stop; and the
  text never says a fake must have its signal handling in before it reports ready. Seven
  are low. The helper behaviours the tests need are not modes. A checklist box names
  SIGTERM where the child may document another stop signal. The vet box drops the
  `GOARCH` that `ci.md` pairs with each Unix, and that pairing is not enough for iOS or
  Android. One sentence reads as if the fake sleeps on exit when it is not race-built.
  Three comments say the SIGKILL path waits for the whole group; it waits for the child.
  And *A CLI terminates* no longer gives a reason that covers its `--watch` ban.
- **2026-10-14 — round four's fixes, never reviewed.** v4.8.1 shipped on Andy's call
  with the gate's first condition unmet. Four rounds of two adversarial passes found 5,
  5, 7 and 6 distinct defects, nearly all in the shell mechanics of `operations/ci.md`
  and `operations/cli-release.md`. After the third, Andy chose one more round and then
  the tag. Round four's fixes, `aafa39f`, touch those two files and
  `checklists/cli-tool.md`. The reference ran them: `./verify.sh` green over 79 gates,
  staticcheck among them, and `make ci` green. No pass has read them. On Andy's call,
  v4.8.2's passes read only its Go pin, which changes two lines in `operations/ci.md`,
  so v4.8.2 ships with the first condition unmet for that document, as v4.8.1 did.
  v5.0.0's passes read only its htmx change, again on Andy's call; it touches neither
  file. The next run's passes cover them.
- **2026-10-27 — round five's fixes, never reviewed.** v5.0.0 shipped on Andy's call with
  the gate's first condition unmet. Five rounds of two adversarial passes found 19, 19, 10,
  11 and 11 distinct defects, the later ones mostly in wording, and Andy chose the tag
  while a sixth round was running, so it was stopped before it reported. Round five's
  fixes, `7bd81fa`, touch `stack/htmx.md`, `stack/html.md`, `patterns/css-motion.md`,
  `patterns/go-file-uploads.md`, `patterns/go-http-client.md`,
  `patterns/go-http-server.md`, `patterns/go-background-work.md`,
  `patterns/htmx-server-rendering.md` and `patterns/htmx-live-updates.md`. The reference
  ran them: `./verify.sh` green over 82 gates and `make ci` green, both under Go 1.27.3.
  No pass has read them. The next run's passes cover them.
- **Measured against v5.0.0:** the cli-tool change path 5,288 → 5,832, all of it the
  checklist's 544, and its floor 11,552 → 12,132 with the widened definition. The
  child-process document is a trigger, 2,791 tokens. Every reach grows by
  `operations/ci.md`'s 66, and cli-tool's by the document and checklist too: cli-tool
  42,416 → 45,853, library 29,717 → 29,783, web-application 104,885 → 104,951. No other
  floor or change path moves.
- **2026-10-31 — the SQLite driver at v1.61.0, and rule 10 guarding the DSN.** `963cacf`
  through `bcbb2aa`. v1.59.0 to v1.61.0 shipped after the v1.58.0 pin, none with an
  advisory, and upstream supports only its latest release. v1.61.0 ends a wait for the lock
  once the context is done, so rule 7 drops "keep every handler deadline above
  `busy_timeout`"; nothing else leaned on it. Measured with two pools over one WAL file, one
  holding the lock and the other writing under a 200 ms deadline, Go 1.27.3: at v1.58.0
  `ExecContext` waited 5,076 ms and `BeginTx` 5,112 ms, the second returning `SQLITE_BUSY`;
  at v1.61.0 both waited 200 ms and returned `context deadline exceeded`.
  **Rule 10 is new and tier 1, on Andy's call.** Andy chose v1.60.0's `StrictPragmas` as
  tier 1 when it was the only guard in view. Review then found the hole it sits behind: a `file:`
  DSN reads the path's `?` as the start of its own query, so `a?b.db` opened a file named
  `a` with `busy_timeout` 0, `x.db?mode=memory&a=` an in-memory database, and an encoded `;`
  in a `_pragma` attached and wrote a second file; `#` ends the name, `%HH` decodes, a
  leading `//` names a host, and `""` and `:memory:` vanish. `openDB` now collapses a
  leading `//`, puts `./` before a relative path and escapes `?`, `#` and `%`: every one of
  28 kinds of path then opened as its own file with all four pragmas. Refusing those
  characters was tried first and broke tests, because `t.TempDir()` keeps `#` and `%` and
  `t.Run` names an unnamed case `#00`; `filepath.Clean` was tried second and folded `..`
  through a symlink as text, opening a different file than the OS means. `VACUUM INTO`
  reads a destination starting `file:` as a URI too, so the snapshot's gets `./`.
  **The run.** Six rounds of two passes, one on facts against the driver source and one on
  the corpus, found 12, 12, 11, 6, 8 and 8 distinct defects; rounds five and six found
  nothing high and round six nothing medium. The first condition is not met; v5.1.0 ships
  on Andy's call, and round six's fixes, `bcbb2aa`, enter Owed unread. **The reference**
  pins `bcbb2aa` in `2870635`: `./verify.sh` green over 82 gates and `make ci` green, both
  under Go 1.27.3 on the Mac. `govulncheck` reports GO-2026-5932 in
  `golang.org/x/crypto` v0.58.0, no fix released and not called.
  `TestTheDSNIsGuarded` fails on every case with the escape removed;
  `TestLockWaitEndsAtTheDeadline` was not run against v1.58.0, whose 5 s wait it bounds.
  **Left open:**
  - **`StrictPragmas`' tier: decided, tier 2, on Andy's call (2026-10-31).** With the path
    escaped, nothing reaches the DSN's query but the constant, so dropping the switch loses
    nothing today; three reviewers held it fails the tier-1 test. Rule 10, the README's
    tier-1 list and both checklists' preambles now name only the path guard. Unreviewed.
  - **`modernc.org/libc`.** The driver says a project must pin the libc its `go.mod` names,
    v1.79.0, and `go get -u ./...` in `operations/ci.md` raises it to v1.79.1. Nothing in
    the corpus holds it back.
  - **An empty database path** is refused nowhere at the config edge: `-database-url=`
    overrides `cmp.Or`'s default, and `openDB` fails only at the first query.
  - **A `..` through a symlink** opens the file the OS means, but the snapshot is built
    from `filepath.Dir`, which folds it as text and lands elsewhere.
  - **Windows paths** — `\data\app.db`, `C:app.db`, UNC — rule 10 says it reads paths the
    Unix way and goes no further.
  - **No box checks closing `Rows`, `Stmt` and `Tx`,** in either checklist, and the CLI's has
    none for the single-writer pool, though the README lists both as tier 1. Older than
    this change.
  - **`go-sqlite.md` keeps `Last verified: 2026-09-08`:** the run read rules 7 and 10, not
    the document. `VERSIONS.md` keeps its date too: CSS Baseline and `design.md` were not
    checked again.
  - **`baseline-ops` was not read:** whether a deployed `DATABASE_URL` holds any of rule
    10's six values is unchecked.
- **Measured against v5.0.0's corpus at `e963d2e`:** `checklists/web-application.md` 4,981
  → 4,999 of 5,000, paid for in part by trimming its section lead; `checklists/cli-tool.md`
  2,881 → 2,902. Change paths: cli-tool 5,832 → 5,892, library 4,310 → 4,350,
  web-application 7,932 → 7,989. Floors: cli-tool 12,132 → 12,192, library 12,464 →
  12,503, web-application 22,168 → 22,225. Reach: cli-tool 45,853 → 46,387, library
  29,783 → 29,822, web-application 104,951 → 105,482.
- **2026-10-31 — seven deviations promoted, on Andy's call.** `4285b2a` through
  `adfd466`. Andy read every project's *Baseline deviations* section and chose the ones
  that recur across projects or name a gap here. `4285b2a` is the shape budget (*Budget
  decisions*). `75a599d`: `stack/makefile.md` rules 1, 4, 5 and 6 — added gate lines and
  build-tag vets, exact pins for a tool whose output ships, variables beside `MAIN`, and
  "no gate reads `.env`". `c2e22e2`: the module path names its owner, and a private
  repository's `go install`. `e388983`: `/healthz` with no database, the `deps_test.go`
  rule, and two cli-tool checklist answers. `adfd466`: new `patterns/wasm-client.md`,
  with `'wasm-unsafe-eval'` in `security-headers.md` — **a tier-1 document, changed**.
  No pass has read any of it, and no `Last verified:` date moved.
  - **Not run:** `make tokens` under GNU Make 3.81 — only 4.4.1 was at hand. The new
    `HEAD` and `TRIGGERS` variables use `\#`, as `REQUIRED` already did.
  - **Not pinned:** TinyGo has no row in `VERSIONS.md`. The pattern makes each project
    name its version; the next re-verification gives it a row.
  - **Not synced:** baseline-reference carries no WebAssembly client, so `verify.sh`
    exercises none of `wasm-client.md`. game and game-lab are its only running copies.
- **Measured against `ab31e65`, after `adfd466`:** heads cli-tool 3,852, library 3,711,
  web-application 3,754. Floors: cli-tool 12,191 → 12,386, library 12,503 → 12,620,
  web-application 22,224 → 22,946. Reach: cli-tool 46,398 → 47,040, library 29,822 →
  30,386, web-application 105,493 → 108,002. `checklists/web-application.md` 4,998 →
  5,345, now a report; its new section 263 of 600.
- **2026-10-31 — TinyGo gets a `VERSIONS.md` row.** Closes the *Not pinned* gap above.
  The row pins **0.42.0** (2026-09-01): the newest release that has built a module here,
  in game and game-lab. 0.44.0 (2026-10-28) is upstream's latest and is held — it could
  not be installed on this machine, so it has built nothing. Both build Go 1.25 through
  1.27 (`minorMin`/`minorMax` at each tag), so the Go row's 1.27.3 sits inside the range.
  `wasm-client.md` rule 1 and `stack/makefile.md` rule 4 now point at the row instead of
  a per-project pin; the version policy gains a TinyGo line and ties a new Go minor to
  it; the checklist box asks for the row's version; the JavaScript row admits the two
  scripts. No pass has read it.
  - **Decided 2026-10-31 by Andy:** one Go row, coupled. A new Go minor waits for TinyGo
    in *every* project, WebAssembly or not; no WebAssembly-only Go floor.
  - **0.44.0 adopted the same day, on Andy's call.** Installed from the release tarball
    (sha256 matching the tinygo-org/homebrew-tools formula); it rebuilt the reference's
    module in `11c10c7`, 45,191 → 51,606 bytes against a 60,000 limit, and
    `./verify.sh` exited 0. game and game-lab still name 0.42.0 in their `make wasm`;
    their `make ci` needs no TinyGo, and each moves when it next rebuilds its module.
  - **Measured under GNU Make 3.81 at this commit,** closing *Not run* above: heads cli-tool 3,852 → 4,032,
    library 3,711 → 3,891, web-application 3,754 → 3,933. Floors: cli-tool 12,386 →
    12,565, library 12,620 → 12,800, web-application 22,946 → 23,132.
    `checklists/web-application.md` 5,345 → 5,351.
- **2026-10-31 — what the reference's WebAssembly client taught the pattern.**
  baseline-reference `fdeaec3` (branch `wasm-client`) implements every rule; building it
  found eleven gaps, folded into `wasm-client.md` and `security-headers.md`: rule 8's
  middleware needs `Unwrap` for `Hijack`, and the socket's goroutines end before the
  session store and database close; the two scripts load deferred in `<head>`, the link
  into the page is `hx-boost="false"`, and the module stops when its canvas leaves the
  document; a 401 from an earlier guard satisfies rule 5; rule 6 names durable state, not
  "a seat"; rule 7 names close codes 1009/1008/1013; rule 3 notes `staticcheck` and
  `go fix` are blind to `js && wasm` files; `.build`/`.sum` are served; a second
  optimizer is pinned like any tool; the loader *may* publish; the CSP token is
  app-wide. **A tier-1 document changed again.** No pass has read any of it.

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
| Mask icons | `img-src data:` | The one directive a default policy would get wrong. |
| Self-hosted font | nothing | Same-origin `.woff2` ([patterns/css-typography.md](patterns/css-typography.md)). A third-party font host would need a `font-src` hole — one reason there isn't one. |
| Web app manifest | nothing | `manifest-src` falls back to `default-src`, and the manifest is same-origin ([patterns/pwa.md](patterns/pwa.md)). |
| View transitions, CSS motion | nothing | Pure CSS ([patterns/css-motion.md](patterns/css-motion.md)). |
| Forms | `form-action 'self'` | Already in the policy. |
| WebAssembly client | `script-src 'self' 'wasm-unsafe-eval'` | Only in an app carrying [patterns/wasm-client.md](patterns/wasm-client.md). Without it no browser compiles the module; `'unsafe-eval'` would also work and would also allow `eval`, so it stays banned. Its socket needs nothing: `ws:` to the page's own host falls under `default-src 'self'`. game and game-lab shipped this token as a conformance note against the gap before it was here. |
| Uploaded files | nothing | A file is served by the app's own handler, so `img-src 'self'` already covers a picture ([patterns/go-file-uploads.md](patterns/go-file-uploads.md)). What keeps that safe is not the policy but three rules in that document: the type comes from sniffing the bytes, `nosniff` makes it binding, and no link to the file is boosted, because htmx parses a boosted answer as HTML whatever its type and ignores both of the other two. A project that ever serves user files from a second origin needs a row here and a directive to match. |

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
