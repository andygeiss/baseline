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
  1.27 (`minorMin`/`minorMax` in `builder/config.go` at 0.42.0,
  `MinimumGoMinorVersion`/`MaximumGoMinorVersion` in `compileopts/config.go` at
  0.44.0), so the Go row's 1.27.3 sits inside the range.
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
    each moves when it next rebuilds its module. (Corrected in review pass 15: game-lab's
    `check` now runs a version-checked `tinygo test`, so its `make ci` needs 0.42.0 and
    is red where only 0.44.0 is installed; it is owed the row, not exempt from it.)
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
- **2026-10-31 — review pass 1.** Three reviewers (contradictions, executed mechanics,
  facts and tier 1) found 16 distinct defects on `promote-deviations`, all fixed. A
  cli-tool box had pushed the child-process secret box out of *Any secret*; it is back.
  The WebAssembly exception now reaches every place stating the absolute rule — the
  *Every* boxes, `project-types/web-application.md`, `stack/htmx.md` (script and GET),
  `go-project-layout.md`, `go-http-server.md`, `SKILL.md`, the JavaScript row — and
  README no longer says a new pattern never lands in the head. `stack/makefile.md` rule 1
  admits rule 5's staticcheck waiver; rule 4 and its three checklist boxes cover
  artifact-producing tools, not formatters, so `fmt`'s `goimports@latest` stands. The
  checklist head lists seven partly-tier-1 sections. Rule 6's cookie clause is tier 1,
  and its box names durable state; the Origin box refuses a missing `Origin`. Rule 8 was
  wrong twice, read in Go 1.27.3's source: `ResponseController` calls a wrapper's own
  `Hijack` before its `Unwrap` (scs v2.9.0 defines one, `session_go120.go:16`), and `Hijack`
  clears the server's deadlines (`server.go` line 326). Rule 3 names `js/wasm`
  `go fix` and staticcheck lines — over `./...`, which pass 2 found fails on a real
  module; `GOOS=js go run …staticcheck` fails with `exec format error`. Rule 5's reason is the `SameSite=Lax` cookie reaching a
  sibling subdomain. The TinyGo source names are `MinimumGoMinorVersion`/
  `MaximumGoMinorVersion` from 0.44.0; the CSP row says `wss:`; the `Permissions-Policy`
  reason no longer claims no script; the size fact is 1,889,724 bytes with `-trimpath`;
  the CSP test matches the banned keywords with both quotes. `make` exits 0: heads
  cli-tool 4,016 → 4,058, library 3,875 → 3,917, web-application 3,918 → 3,994; floors
  12,550 → 12,602, 12,784 → 12,837, 23,127 → 23,357; `checklists/web-application.md`
  5,351 → 5,407. No pass has read the fixes.
- **2026-10-31 — review pass 2.** Three reviewers found 14 distinct defects on
  `promote-deviations`, all fixed. `wasm-client.md` rule 6 and its box re-resolve the
  cookie's session, and the user it names, at a fixed interval or per message and close
  with 1008 once either is gone, so a logout, a revoking reset, or a deleted account
  reaches an open socket; README's tier-1 list names that and the missing `Origin`. A
  WebAssembly client's `script-src` is the second directive a default policy gets wrong.
  The banned keywords match case-folded, and `TestSecureHeaders` now checks them —
  compiled, run, `go vet` and staticcheck clean under Go 1.27.3. Rule 3's `go fix` and
  staticcheck lines run over the vet line's package list: over `./...` both fail on
  baseline-reference `11c10c7` in `modernc.org/libc`; over the list both pass and each
  catches a planted finding. `stack/makefile.md` rule 1's tag vet is for custom tags,
  not GOOS/GOARCH; the pinned-tool boxes say committed or flashed, not `go build`. The
  program-page exception reaches `project-types/web-application.md`, `stack/html.md`,
  and `stack/htmx.md` rule 8; four WebAssembly boxes are new (head scripts, the unboosted
  link, the canvas stop, deadlines after `Hijack`) and shutdown precedes the store
  closing. Both checklist heads name two tier-1 `.env` boxes. The `Permissions-Policy`
  reason and the RFC 6455 citation (sections 4.1 and 10.2) are exact. Pass 1's fixer
  wrongly said scs has no `Hijack`; `a181e8f` corrected it. `make` exits 0: heads
  cli-tool 4,058 → 4,062, library 3,917, web-application 3,994 → 3,999; floors 12,602 →
  12,623, 12,837 → 12,853, 23,357 → 23,719; reach web-application 109,204 → 109,877,
  and cli-tool 47,329 → 49,748 and library 30,676 → 33,090 because their OS-vet boxes
  now point at `wasm-client.md`;
  `checklists/web-application.md` 5,407 → 5,534, its WebAssembly section 385 of 600. No
  pass has read the fixes.
- **2026-10-31 — review pass 3.** Three reviewers found 16 distinct defects on
  `promote-deviations`, all fixed. A socket served inside its handler resurrected a
  revoked session: scs v2.9.0's `LoadAndSave` commits after the handler returns, `Load`
  marks every session modified under `IdleTimeout`, and `Hijack` never sets `written`,
  so the handshake's copy was saved again after a logout deleted it — proven by an
  executed test (scratchpad `resurrect/main_test.go`, Go 1.27.3). `wasm-client.md` rule 8
  now returns right after the handshake, tier 1, with a box; rule 6 re-reads the store
  (`Load` into a fresh context, not `Get`) at most every 10 seconds, fails closed with
  1011, covers a machine token, a stateless signed cookie, and the idle deadline a socket
  never refreshes, and is tier 1 whole; rule 7's message-size cap is tier 1, in the
  header, README's list and the checklist. `go-data-deletion.md` points an open socket at
  rule 6. Rule 3's list is this module's own packages (`{{with .Module}}{{if .Main}}`),
  checked on archives of game `442d9dd` and baseline-reference `ef68418` and on a module
  importing scs, which the old list kept; rule 2's digest lists files with
  TinyGo's own tags, which change nothing on either; `-tags tinygo` alone, the fix as first
  written, missed nine of the ten `tinygo info -target wasm` prints (0.44.0), corrected
  before pass 4. The three OS-vet boxes and
  `operations/ci.md` send js/wasm to that `check` line, not `./...`; the custom-tag vet
  excludes `ignore` (`go vet -tags ignore ./...` fails, Go 1.27.3) and `unix`. Rule 4
  calls `deps_test.go` a denylist on purpose. `stack/htmx.md` narrows "a `<head>` that
  differs" to one loading a script or stylesheet the current page does not. The program
  page's links out are unboosted too, since htmx 4.0.0's Back and Forward restore only
  the body — read in the vendored `htmx.min.js`, **unverified in a browser**. `SKILL.md`
  value 3 points at the program page; README's checklist-budget line no longer
  contradicts the shape-budget entry. `make` exits 0: heads cli-tool 4,062 → 4,087,
  library 3,917 → 3,942, web-application 3,999 → 4,032; floors 12,623 → 12,665,
  12,853 → 12,895, 23,719 → 23,854; `checklists/web-application.md` 5,534 → 5,620, its
  WebAssembly section 385 → 446 of 600. No pass has read the fixes.
- **2026-10-31 — review pass 4.** Reviewers found 11 distinct defects on
  `promote-deviations`, all fixed. `wasm-client.md` rule 6 re-reads the store in a
  context not derived from the request's: after `Store.Delete`, scs v2.9.0's
  `Load(context.WithoutCancel(r.Context()), token)` still found the user and
  `Load(context.Background(), token)` did not — an executed test (scratchpad
  `fix4/scs`, Go 1.27.3); `go-background-work.md` and the box carry the exception. The
  re-read has a deadline inside the interval, a miss closes with 1011, and the socket
  acts on nothing while a check is overdue; it creates or changes no durable state
  (header, rule, README's tier-1 list, box); only a cookie that reaches no server record
  skips the re-read. Rule 7 counts a whole message across its fragments before a payload
  is read and caps control frames at 125 bytes (RFC 6455 sections 5.4, 5.5). Rule 3's
  list, vet, `go fix` and staticcheck lines take `-tags $(WASM_TAGS)`, which `make wasm`
  checks against `tinygo info -target wasm` with the module's flags, and fail closed on a
  failing or empty list (`$$` in a Makefile); rule 2's digest lists Go and embedded files
  under those tags, which the `.build` records so `make ci` needs no TinyGo. On an archive
  of baseline-reference `b8542dc` under GNU Make 3.81 a planted `tinygo`-tagged file
  passed the old vet and left the old digest unchanged, and the tagged lines caught both;
  an unescaped `$` or an empty list exited 0 in the old form, 2 in the new. The
  checklist splits handler-return and message-size from their tier-2 neighbours;
  `go-project-layout.md` rule 3 names the browser denylist; `stack/htmx.md` moves the
  program-page links, into and out of it, from tier-1 rule 8 to the `hx-boost` row, and
  the layout's shared links out take a per-page hook; the 1.9 MB fact names `go 1.27`. `make` exits 0: `wasm-client.md` 3,109 → 3,604 of 3,800,
  floor web-application 23,854 → 23,908, heads unchanged, `checklists/web-application.md`
  5,620 → 5,673, its WebAssembly section 446 → 498 of 600. No pass has read the fixes.
- **2026-10-31 — review pass 5.** Reviewers found 12 distinct defects in the baseline,
  all fixed, and 3 in the reference, fixed there separately. Links out of the program
  page need no `hx-boost="false"`: vendored htmx 4.0.0's restore calls
  `location.reload()` when `history` is `"reload"`, which the canonical `htmx-config`
  sets, so the per-page hook is gone (`wasm-client.md`, the box, the `hx-boost` row).
  Rule 6 closes on lost access too (a lost membership) and acts on nothing while a due
  check is unanswered; the box and README say "re-resolved", as a stateless cookie is
  not re-read. Rule 7 cites RFC 6455 section 10.4, caps frames a second, and closes a
  malformed socket with 1002; the size box names the 125-byte control cap. The server
  test holds the `.build` to the Makefile's version, flags and tags; `deps_test.go`'s
  browser list runs under `js/wasm` and those tags; an exported TinyGo function carries
  `//lint:ignore U1000`. `stack/makefile.md` rule 1 exempts TinyGo's tags from the
  custom-tag vet (host `go vet -tags tinygo ./...` exits 1 on `syscall/js`), and the
  three checklists with it; an added `go fix -diff` line brings its `go fix` into
  `fmt`; rule 5's variable is for a value two places must agree on. Executed in
  scratchpad `fix5/m`, Go 1.27.3, TinyGo 0.44.0, staticcheck 2026.2.2: U1000 on
  `//export` and `//go:wasmexport` until the ignore, the module still exporting both;
  the `js/wasm` `go fix -diff` exits 1 where the host's exits 0, and `go fix` clears it;
  the tagged `js/wasm` `go list -deps` reaches `syscall/js`, the untagged one does not.
  `make` exits 0: `wasm-client.md` 3,604 → 3,656 of 3,800, `stack/makefile.md` 3,110 →
  3,171, floors cli-tool 12,665 → 12,679, library 12,895 → 12,909, web-application
  23,908 → 23,949, heads unchanged, checklists cli-tool 3,096 → 3,110, library 1,472 → 1,486,
  web-application 5,673 → 5,692, the WebAssembly section 498 → 504 of 600. No pass has read the fixes.
- **2026-10-31 — review pass 6.** Reviewers found 12 distinct defects in the baseline,
  all fixed; the reference's are fixed there separately. `wasm-client.md` rule 6 re-runs
  the handshake's resolver and access check, not only scs `Load`, which still succeeds
  for a deleted person's session. A boosted form into the program page never starts the
  module either, so the opt-out covers a link or form whose answer is that page; a
  boosted link out of a page whose `<head>` adds a stylesheet leaves it styling the
  next, so the `hx-boost` row covers that too. Headless Chrome confirmed Back after a
  boosted link out of the map page reloads it (Chromium only). Rule 7's control-frame
  cap is tier 1 in the header and README, 1002 in the box; the box caps frames a second.
  Rule 2's digest uses rule 3's `go list`: run on the host it drops `_js.go` files. Rule
  4 names `golang.org/x/sync/...`, since that module has no root package. The js/wasm
  `go fix` and staticcheck lines join the fixer switch and the staticcheck hold-back; an
  added `go fix -diff` gets a bounded `fmt` loop (the review ran one pass: `check`
  stayed red). The OS-vet boxes and `ci.md` scope js/wasm to a WebAssembly client; the
  TinyGo-tag exemption covers only packages rule 3 vets. `make wasm`'s version test is a
  gate, not a branch, and required targets do not count against one screen. Executed
  (scratchpad `fix6/m`, Go 1.27.3): host `go list -deps` omits a `_js.go` file the
  js/wasm one lists; a `tinygo`-tagged error in a package the main package does not
  import passed host vet and the js/wasm line; `golang.org/x/sync` v0.18.0 has no root
  `.go` file. `make` exits 0: `wasm-client.md` 3,656 → 3,685 of 3,800,
  `stack/makefile.md` 3,171 → 3,231, `operations/ci.md` 2,451 → 2,464, floors cli-tool
  12,679 → 12,690, library 12,909 → 12,920, web-application 23,949 → 23,992, heads
  unchanged, checklists cli-tool 3,110 → 3,122, library 1,486 → 1,498, web-application
  5,692 → 5,716, the WebAssembly section 504 → 516 of 600. No pass has read the fixes.
- **2026-10-31 — review pass 7.** Reviewers found 9 distinct defects in the baseline,
  all fixed, and 2 in the reference, fixed there separately. Rule 7 reads a frame's
  declared length unsigned, its top bit 0 (RFC 6455 section 5.2): read signed, a
  negative length passes the cap and panics in `make` on the socket's goroutine, proven
  by executed code. The tier-1 line is "no stored record" in the header, rule 6, README
  and box; memory-only state, like a board, is the socket's. Rule 6 keeps the presented
  credential and re-runs the resolver's lookup (scs `Load`, a token's hash) and the
  access check as a store read made as that user. "A link out needs nothing" is scoped
  to Back and Forward; the `hx-boost` row's stylesheet case covers a form too (headless
  Chrome). `fmt` runs one loop until every `-diff` line is empty; the fixer switch is
  on every `go fix` command in `check` and `fmt`; `ci.md`'s staticcheck lines are
  plural; the close codes moved to the tier-2 frames box. The TinyGo-tag vet runs over
  the packages rule 3's list leaves out: in scratchpad `fix7/m`, GNU Make 3.81, Go
  1.27.3, `go vet -tags $(WASM_TAGS) ./...` exits 2 on a browser file's `syscall/js`,
  the scoped line catches a planted error in a server `tinygo` file and exits 0 once
  it is fixed. `make` exits 0: `wasm-client.md` 3,685 → 3,767 of 3,800,
  `stack/makefile.md` 3,231 → 3,293, `operations/ci.md` 2,464 → 2,457, `stack/htmx.md`
  2,096 → 2,094, floors cli-tool 12,690 → 12,692, library 12,920 → 12,922,
  web-application 23,992 → 24,021, heads unchanged, checklists cli-tool 3,122 → 3,124,
  library 1,498 → 1,500, web-application 5,716 → 5,747, the WebAssembly section 516 →
  545 of 600. No pass has read the fixes.
- **2026-10-31 — review pass 8.** Reviewers found 9 distinct defects in the baseline,
  all fixed. Rule 7 compares a fragment's length with what the cap has left
  (`n > max-total`), never a sum: in scratchpad `fix8/ovf`, Go 1.27.3, a length of
  2^63-1 passes the unsigned read, `total+n` wraps negative, passes the cap and panics
  in `make`, where the difference form refuses it. Rule 6's tier-1 line is by role,
  not medium — the socket makes or changes nothing that says who may act, in a store or
  in memory — the same phrase in the header, rule 6, README and box; its re-check only
  reads (no `last_used_at`, no `Destroy`, recorded as Claude's decision), with a pointer
  in `go-auth-sessions.md` rule 6. Every recipe that runs `tinygo` checks its version,
  `check`'s `tinygo test` line too (`stack/makefile.md` rule 4): in `fix8/allocs` one
  zero-allocation test passes under TinyGo 0.42.0, whose `AllocsPerRun` returns 0, and
  fails under 0.44.0. A `syscall/js` file carries `js && wasm` (rule 1): in `fix8/tagjs`,
  GNU Make 3.81, a `tinygo`-only file in a package the server imports fails the scoped
  TinyGo vet line, exit 2, and `tinygo && js && wasm` exits 0 with TinyGo still
  building. `stack/html.md` gives the layout a `{{block "head" .}}{{end}}` slot before
  htmx (executed: a page without `head` renders nothing there). Also: "Message and
  control-frame sizes are tier 1", the live-updates "never pushes" exception, and the
  custom-tag box naming rule 1's TinyGo line. `make` exits 0: `wasm-client.md` 3,767 →
  3,773 of 3,800, `stack/makefile.md` 3,293 → 3,409, `stack/html.md` 1,329 → 1,375,
  floors cli-tool 12,692 → 12,709, library 12,922 → 12,939, web-application 24,021 →
  24,117, heads unchanged, checklists cli-tool 3,124 → 3,140, library 1,500 → 1,517,
  web-application 5,747 → 5,797, the WebAssembly section 545 → 578 of 600. No pass has
  read the fixes.
- **2026-10-31 — review pass 9.** Reviewers found 6 distinct defects in the baseline,
  all fixed, and 1 in the reference, fixed there separately. "Says who may act" was
  undecidable, since whose turn it is says who acts next: the tier-1 line is now the
  authorization boundary — the socket makes or changes nothing a credential resolver or
  access check reads (an identity, a session, a membership, a ban, a host), the same
  phrase in the header, rule 6, README and box, and a board or whose turn it is stays
  the socket's. Rule 6 drops "it never remembers the user"; the box gains "acts on
  nothing while a check is due"; the background-work box excepts work that re-reads a
  session (the app's context); the pinned-tool box in all three checklists says every
  recipe running the tool checks its version first. The TinyGo-tag vet is an ordinary
  `go vet -tags $(WASM_TAGS) ./...`, unscoped, now that a `syscall/js` file carries
  `js && wasm`: in scratchpad `fix9`, GNU Make 3.81, Go 1.27.3, it exits 0 on archives
  of baseline-reference 9f8387c, game-lab 6e379aa and game `baseline-promotions`, and a
  planted `tinygo`-only `syscall/js` file makes it exit 2. `make` exits 0:
  `wasm-client.md` 3,773 → 3,769 of 3,800, `stack/makefile.md` 3,409 → 3,387, floors
  cli-tool 12,709 → 12,685, library 12,939 → 12,915, web-application 24,117 → 24,118,
  heads unchanged, checklists cli-tool 3,140 → 3,116, library 1,517 → 1,493,
  web-application 5,797 → 5,798, the WebAssembly section 578 → 578 of 600, background
  work 198 → 224. No pass has read the fixes.
- **2026-10-31 — review pass 10.** Reviewers found 6 distinct defects in the baseline,
  all fixed; the reference's are fixed there separately. The mechanics reviewer built a
  new WebAssembly client from the docs alone: `make wasm`, `check`, `fmt` and `ci` green,
  and the module drew in headless Chrome under the CSP. "Nothing a credential resolver
  or access check reads" forbade the board the access check reads with its row: the
  tier-1 line is now nothing that decides who passes one, the same phrase in the header,
  rule 6, README and box; a stored board or a move row is the socket's, and a room, its
  owner or host, a membership take a form. Rule 6 adds that a close may drop what its
  user held and grants nothing (a host handed on by event order is a grant), drops
  `context.Background()` for the app's own context as `go-background-work.md` names,
  and sends shutdown's cancel to rule 8's 1001, not 1011. `stack/makefile.md` rule 1:
  every file in a package the host cannot build carries `js && wasm`, not only one
  importing `syscall/js` — in scratchpad `fix10/tag`, Go 1.27.3, TinyGo 0.44.0, a
  `tinygo`-only file beside a `js && wasm` one fails `go vet -tags $WASM_TAGS ./...`
  with "undefined: Doc", exit 1, and exits 0 as `tinygo && js && wasm`. The version
  check is for an installed binary (`tinygo`, `wasm-opt`); a `go run …@$(V)` line is
  its own check, since stringer v0.52.0 rejects `-version`, exit 2 (rule 4 and the
  pinned-tool box in all three checklists). Rule 5 says "any other origin of the same
  site". `make` exits 0: `wasm-client.md` 3,769 → 3,764 of 3,800, `stack/makefile.md`
  3,387 → 3,439, floors cli-tool 12,685 → 12,701, library 12,915 → 12,931,
  web-application 24,118 → 24,133, heads unchanged, checklists cli-tool 3,116 → 3,133,
  library 1,493 → 1,509, web-application 5,798 → 5,813, the WebAssembly section 578 →
  576 of 600. No pass has read the fixes.
- **2026-10-31 — review pass 11.** Five defects, all wording; the reference at
  `3de5087` followed every rule checked, and the mechanics reviewer built a second
  WebAssembly client from the docs alone (a shared drawing board: `make wasm`, `check`,
  `fmt`, `ci` green under GNU Make 3.81; the module ran and its socket opened in headless
  Chrome under the CSP). Fixed: rule 6's close clause had no limit, so a shutdown, a
  store error or an attacker-forced 1013 could delete stored rooms, memberships or host
  roles; a close now drops only its user's hold in memory. `stack/htmx.md`'s `hx-boost`
  row let a link between two program pages stay boosted (same scripts, so "a script the
  other does not" never fired); it now reads "a script of its own". `stack/makefile.md`
  rule 1 now covers a package both builds compile (the counterpart carries
  `!tinygo || !js || !wasm`, executed) and no longer says every `tinygo`-only file fails
  the TinyGo-tag vet, only one that imports `syscall/js` or uses a sibling's name
  (executed). The tier-1 credential box gains pass 10's shutdown 1001. `make` exits 0:
  `wasm-client.md` 3,764 → 3,757, `stack/makefile.md` 3,439 → 3,467, `stack/htmx.md`
  2,094 → 2,092, floor web-application 24,133 → 24,138, checklist web-application
  5,813 → 5,820, the WebAssembly section 576 → 583 of 600. No pass has read the fixes.
- **2026-10-31 — review pass 12.** Six defects; a third WebAssembly client written from
  the docs alone (two-player Nim, rooms by form, moves over the socket) went green under
  GNU Make 3.81 (`make wasm`, `check`, `fmt`, `ci`), its hand-written frame reader
  passed every attack (fragments, 2^63-1 on a continuation, oversized and fragmented
  control frames, 31 frames a second), its re-check closed 1008 on logout, leaving and
  account deletion, 1011 on a slow store and 1001 on shutdown mid-check, and in headless
  Chrome a move crossed between two players under the CSP. Fixed: rule 6 said a plain
  form alone makes, changes or deletes an identity, session, room or membership, which
  outlawed session expiry, game's room timeouts and the reference's own JSON room API;
  it now reads an ordinary HTTP request (a form, an API call) or the app's own expiry,
  never the socket. "A close may drop its user's hold" named nothing; the socket may now
  give up only its own user's in-memory seat, membership or host role, by a message or a
  close, and hands it to no one (game's in-canvas Leave conforms), with the same
  exception in the header, README and box. Rule 6 now acts with the access the latest
  check returned, so a demoted host stops acting as host. `stack/makefile.md` rule 1: the
  `fmt` loop computes the js/wasm list once before it, failing closed (executed: the
  list was empty on the first pass), and a counterpart negates its file's constraint
  exactly, with every case that fails the TinyGo-tag vet named (executed: "now
  redeclared"). The pass-11 entry gains its missing numbers. `make` exits 0:
  `wasm-client.md` 3,757 → 3,795 of 3,800 (the idle-window aside and a restated `Get`
  clause cut to pay), `stack/makefile.md` 3,467 → 3,505, floor web-application 24,138 →
  24,148, checklist web-application 5,820 → 5,830, the WebAssembly section within 600. No
  pass has read the fixes.

- **2026-10-31 — review pass 13.** Six defects. A fourth WebAssembly client from the docs
  alone (a buzzer room) went green under GNU Make 3.81 and drew in headless Chrome under
  the CSP with no CSP errors; a hand-written rule-6 server passed logout, slow-store,
  shutdown, Leave and demotion tests. Fixed: pass 12's entry was wrong that the header,
  README and box carried rule 6's exception: the header's "seat aside" exempted the seat
  outright (so the socket could claim one) and all three named only the seat. Rule 6 now
  names the user's "hold in memory — a seat, membership or host role", given up "to no
  one", and the header, README and box say the same. "Acts with the access the latest
  check returned" was in rule 6 alone; one changed line in the reviewer's server kept a
  demoted host resetting while every box still passed (executed), so the header, README
  and box carry it. "The app's own expiry" was unbounded and let a close-started expiry
  delete stored state again (pass 11's hole); a stored one is never started by a close.
  Rule 6 now says a stored board or move row is written as go-authorization.md says, so a
  removed member's write fails at once, not after the next check. `stack/htmx.md`'s
  litmus line gains the WebAssembly exception. `stack/makefile.md` rule 1: only a name a
  `js && wasm` file declares fails the TinyGo-tag vet (executed). Cut to pay: "(a form, an
  API call)", "whether or not the client sends anything" → "unprompted", the restated
  `Get` clause. `make` exits 0: `wasm-client.md` 3,795 → 3,783 of 3,800,
  `stack/makefile.md` 3,505 → 3,511, `stack/htmx.md` 2,092 → 2,116, floor
  web-application 24,148 → 24,178, checklist web-application 5,830 → 5,836, the
  WebAssembly section within 600. No pass has read the fixes.

- **2026-10-31 — review pass 14.** Nine distinct defects. A fifth WebAssembly client from
  the docs alone, SQLite-backed "Pixel Room", went green under GNU Make 3.81 and drew in
  headless Chrome. Andy decided two things the same day. The re-check's mechanics moved
  out of `wasm-client.md` rule 6 into a new tier-1 section of `go-auth-sessions.md`,
  *Re-resolving a long-lived connection* (the read-only lookup, scs `Load` into the app's
  own context and why never `context.WithoutCancel`, the deadline, the stateless cookie,
  the idle window, and the scs `Load` fact); rule 6 keeps the statement and points there,
  as do `go-background-work.md`, `go-data-deletion.md` and the two checklist boxes. And a
  cap on in-memory presence that grants no privilege is a resource limit, so the socket
  may take or free a seat, which makes game-lab and baseline-reference conform. Fixed:
  "at most every 10 seconds" (a rate limit, and "that interval" dangled) → "at least …
  inside the interval"; the header gains "read-only" and "closed once it, its user, or
  its access is gone", agreeing with README and the box; a stored expiry is "never
  started by the socket", not "by a close", and an expiry in memory grants nothing; the
  stateless cookie's lookup checks only an expiry and the access check still runs; a row
  written under a membership names it in its own statement (`INSERT … SELECT … FROM
  members WHERE room_id = ? AND user_id = ?`, now `go-authorization.md` rule 6, its box
  "ownership or membership"), and an in-memory membership is checked in the write's
  step, under its lock — executed on modernc sqlite v1.61.0, the `VALUES` form stored a
  removed member's move (1 row), the `SELECT` form stored none (0 rows) and a member's
  (1 row). `stack/makefile.md` rule 1's fmt template gains `n=3 &&` and says a `;` after
  the list fails open (executed under 3.81: a failing or empty list exits 2 with `&&`, 0
  with `;`; without the counter the loop exits 1 before its first `go fix`); its failure
  list now names a package made only of `js && wasm` files and a name a `_js.go` or
  `_wasm.go` file declares (each executed under TinyGo 0.44.0's tags: all exit 1). `make`
  exits 0: `wasm-client.md` 3,783 → 3,628 of 3,800, `go-auth-sessions.md` 3,061 →
  3,533, `go-authorization.md` 2,120 → 2,209, `go-background-work.md` 2,486 → 2,497,
  `go-data-deletion.md` 3,172 → 3,202, `stack/makefile.md` 3,511 → 3,559, the
  WebAssembly section 599 → 570 of 600, checklist web-application 5,836 → 5,812, floor
  web-application 24,178 → 24,154, head 4,032 → 4,034. No pass has read the fixes.
- **2026-10-31 — review pass 15.** Six defects; the mechanics reviewer found **zero** for
  the first time — a sixth docs-only client (a SQLite dice tower with machine tokens)
  went green under GNU Make 3.81, also with TinyGo off `PATH` for `make ci`, its
  re-check written from *Re-resolving a long-lived connection* alone closed correctly for
  logout, revocation, deletion, lost membership, slow store, shutdown and idle window,
  and headless Chrome confirmed both the `'wasm-unsafe-eval'` and boosted-form claims.
  Fixed: pass 14's box split dropped "acts on nothing while a check is due" and the 1011
  close, which the new auth section never carried, so a fail-open re-check passed every
  box; the box carries both again. The capacity clause's "grants no privilege" was
  undecidable and its example, "a seat", could be a player's seat moves are checked
  against (a membership); it is now stated in rule 6's own terms. A membership held in
  memory had no form go-authorization.md allowed (SQL only, never a Go comparison); both
  documents and the box now name the in-memory case: check and write in one step, under
  its lock. The stateless-cookie clause asked for an access check with no subject; it
  runs for what the cookie names, and a cookie naming nothing has nothing to re-check.
  The TinyGo 0.44.0 entry said game-lab's `make ci` needs no TinyGo; corrected in place.
  `make` exits 0: `wasm-client.md` 3,628 → 3,672, `go-auth-sessions.md` 3,533 → 3,560,
  `go-authorization.md` 2,209 → 2,247, checklist web-application 5,812 → 5,853, floor
  web-application 24,154 → 24,195, the WebAssembly section 570 → 593 of 600. No pass
  has read the fixes.
- **2026-11-01 — review pass 16.** Nine defects. The mechanics reviewer's seventh
  docs-only client, "Tug Room" (in-memory rooms, no database), went green under GNU Make
  3.81 and in headless Chrome. Fixed: "a membership held in memory" also matched a stored
  one cached in memory, so a removed member's move could be stored past a stale cache;
  it is now "held only in memory" in `wasm-client.md` rule 6, `go-authorization.md`
  rule 6 (which adds that a stored, cached membership is a stored one) and the box —
  raced 2,000 times, the in-memory one-step check stored 0 moves after removal, the
  two-step form 3,552. The in-memory case contradicted `go-authorization.md`'s headline,
  rule 2, tier stamp and box, and README's tier-1 list; each now points to rule 6. That
  Go check had no test: *Testing* and a box now ask for a non-member and a removed
  member, refused with 1008, nothing stored. *Re-resolving a long-lived connection* rule
  4 re-checked only what a stateless cookie names, so a socket admitted by its URL's
  room was never re-checked (proven executed: an anonymous socket kept a private room's
  state); it now re-runs whatever the handshake checked. The session-re-read clause left
  the tier-2 background-work box; the socket's re-resolve box covers it. The custom-tag
  boxes name `$(WASM_TAGS)`. The scs and U1000 facts say they were executed (re-run on scs v2.9.0,
  Go 1.27.3, staticcheck 2026.2.2, TinyGo 0.44.0), and a new fact sources the close
  codes: 1013 is IANA's, not RFC 6455 section 7.4.1's (both fetched). The machine-token
  box said "32 random bytes" where the code calls `rand.Text()`. `make` exits 0:
  `wasm-client.md` 3,672 → 3,755, `go-auth-sessions.md` 3,560 → 3,612,
  `go-authorization.md` 2,247 → 2,362, the WebAssembly section 593 unchanged, checklist
  web-application 5,853 → 5,896, floor web-application 24,195 → 24,238. No pass has read
  the fixes.
- **2026-11-01 — v5.2.0 ships on Andy's call.** Sixteen passes found 16, 14, 16, 11, 12,
  12, 9, 9, 6, 6, 5, 6, 6, 9, 6 and 9 distinct defects, so the gate's first condition is
  not met; pass 16's fixes, `a5975cb`, enter Owed unread. **The reference** pins
  `a5975cb` in `51681c3`: `./verify.sh` green over 86 gates and `make ci` green, both
  under Go 1.27.3 and TinyGo 0.44.0 on the Mac.

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
