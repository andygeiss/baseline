# Verification Record

**Last verified: 2026-09-05**

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
3. The reference's `SPEC.md` pins that commit and carries the four-field brief, and
   its own tag mirrors the baseline version.
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

**The budget boundary, settled.** The four budget sentences in README.md *Size budgets*
said "stays under" where `make tokens` fails only above the number; they now say "stays
within", so a document at exactly 3,800 is what both mean. The numbers did not move.
Owed: a pass over the four sentences and the record.

## Run log

Newest first.

### 2026-09-05 — the two decisions, decided (v4.5.0)

**`encoding/json/v2` is the JSON package, and the ruling grew from one sentence to three
cases because the corpus's own release rules made it.** The first draft said "an
existing call site moves the first time a change touches it", which is right for a web
application and wrong for anything tagged: the move changes what goes out — a nil slice
is `[]`, a zero number survives `omitempty`, `<` is not escaped — and what is accepted —
names match case-sensitively, a duplicate name and invalid UTF-8 are errors — and
[operations/cli-release.md](operations/cli-release.md) calls a breaking change to the
observable contract a major, [go-library.md](patterns/go-library.md) says the same of
observable behavior consumers rely on. So a contract a tag promises moves at its next
major. Then the v0 line: [project-types/library.md](project-types/library.md) lets v0
break freely, cli-release.md has no v0 clause at all, so a library's wire format is a
contract from v1 and a CLI's `-json` at any tag. A web application's `/api` has no
semver contract and ships with the next deploy. Four passes, each adding a case the
previous wording could not be followed under; none was a fact about Go, every one was an
unchanged document read against the new sentence.

**Every default and bullet was run, and the running is what the rules are made of.**
Under go1.27.1, in a `go 1.27` module, with no experiment flag: v2 leaves a field empty
on a name in the wrong case, rejects a duplicate name and invalid UTF-8, marshals nil
slice and map as `[]` and `{}`, keeps a zero number and bool under `omitempty` and also
a zero `time.Time` — `"0001-01-01T00:00:00Z"` — and a zero struct, all four of which
`omitzero` drops; marshals map keys in map order, 17 distinct byte strings over 50 runs,
one under `json.Deterministic(true)`; writes no newline from `MarshalWrite` where v1's
`Encoder.Encode` wrote one; rejects a second object after the first in `UnmarshalRead`
and accepts trailing whitespace; accepts every `Options` value `encoding/json` exports,
so the "never pass one" bullet guards a path that compiles; and emits `<a>&` verbatim
where v1 wrote `\u003ca\u003e\u0026`. Under go1.26.7 in a `go 1.26` module the package
does not build at all — "build constraints exclude all Go files" — which is what "(Go
1.27+)" on the row measures. The first draft got one of these wrong: it sent a nil
pointer to `omitzero`, and v2's `omitempty` already omits it because a nil pointer
encodes as `null`.

**The `omitzero` fixer does not do what its name says, and the fix gate will show a
project that.** Under the pin, `go fix -diff` on a struct with `time.Time` under
`omitempty` strips the tag to a bare name — behavior-preserving, since v1 never omitted
a struct — and prints that it is ignoring the alternative "Replace omitempty with
omitzero (behavior change)". So `make check` goes red on such a field, `make fmt`
deletes the tag rather than upgrading it, and the `omitzero` the reader wanted is
written by hand, which is what the bullet in [stack/go.md](stack/go.md) says to do. The
reference has one `omitempty`, on a map, which the fixer leaves alone; the two
repositories the v4.4.0 entry found red under `go fix -diff` at 1.27.1 may be red for
this reason among others.

**htmx 4.x has a trigger instead of an open ban, and the record carries what the trigger
will need.** The policy bullet in [VERSIONS.md](VERSIONS.md) is the one place that
rules: 4.0.1 shipping starts a baseline release that adopts 4.x, and projects move with
that release, not with the patch — the Go policy's first-patch trigger without the Go
policy's *needs a new feature immediately* exception, because a project on 4.x before
the layout, the 422 flow, and the history rule move with it would be a project the
checklist cannot check. The 4.x row in VERSIONS.md and the warning in
[stack/htmx.md](stack/htmx.md) say what 4.x is and point at the bullet for the rule,
after a pass found the same rule ruled three times on the floor. What that release will
find, read at four.htmx.org and checked key by key: inheritance is explicit —
`hx-boost:inherited="true"` on the body, `implicitInheritance` false — and of the five
keys the canonical `htmx-config` sets, `includeIndicatorStyles` is
`includeIndicatorCSS`, `globalViewTransitions` is `transitions`, `historyCacheSize` and
`refreshOnHistoryMiss` are `history` taking true, `"reload"`, or false, and
`responseHandling` is `noSwap`, `[204, 304]` by default, so a 4xx swaps unless named.
npm's `latest` still names 2.0.10 and no 4.0.1 exists.

**One line beside a fence was rewritten five times, and the fifth is the shortest.**
"Five things there are not optional" gained a sentence naming the package the fence
imports, and every phrasing of that sentence bound "there" or "that fence" to the wrong
noun for one reviewer or another — the package, the list, the fence. What stands is
"`json` is `encoding/json/v2`. Five things are not optional:", two sentences with no
pointer in either, and the lesson is STYLE.md's re-read test applied twice: a pointer
that can bind to two nouns is removed, not moved.

**95 defects over 17 passes, two lenses each; passes sixteen and seventeen clean on
both.** 14, 19, 9, 6, 9, 6, 2, 4, 3, 4, 6, 5, 4, 2, 2, then nothing. The facts lens
found 13 in all and was clean from pass three except where the record described a change
it did not contain — a checklist box deleted and unrecorded, "two JSON surfaces" where
the reference has one, a "pay for" the token count contradicted — or where a rule read
against an unchanged document: the v0 line, the web application's tag. The writing lens
found the rest, and from pass seven on nearly all of them were in *Owed*, the paragraph
every pass rewrote: each new sentence there was fresh surface, which the v4.4.0 entry's
own pass counts show. Two reviewers reversed each other twice — one bullet or two for
map order and tests, "there" or not beside the fence — and the resolution both times was
to state the scope the second reviewer missed rather than pick a side.

**A trim that changes a rule's meaning is a rewrite, and one pass caught the record
calling it a shortening.** go-http-client.md sat at 3,796 of 3,800 before the change and
the added sentence took it to 3,801; rule 4 gave back the words — "1 MiB, or a larger
cap the API documents" says what "unless the API documents a larger legitimate response"
said — and a pass caught the first trim changing the rule's meaning while the record
called it a shortening. The README's "stays under" and the Makefile's fail-above still
disagree at the boundary, noted last run and not settled; this change did not land on
it.

**The budgets held.** The web change path is 7,923 → 7,945 of 8,000: the htmx row and
the policy bullet grew, then the row and the warning were cut to pointers. The floor is
20,304 → 20,750: 409 of it the row, the ruling paragraph, and its eight bullets in
[stack/go.md](stack/go.md), the rest the htmx row in VERSIONS.md and the warning in
stack/htmx.md. The cli-tool change path is 5,231 → 5,253. go-http-client.md is 3,796 →
3,796.

**The empirical half:**
[baseline-reference](https://github.com/andygeiss/baseline-reference) `ede246d`, tagged
v4.5.0, pinning baseline `9035558`. Seven files moved to `encoding/json/v2`. The `/api`
decoder lost its second `Decode`: `UnmarshalRead` with `RejectUnknownMembers(true)`
refuses an unknown field and a second object in one call, and a body over the cap still
reaches the same `errors.As` on `*http.MaxBytesError` through it — a 413, now tested,
beside a new case for a field in the wrong case, which v1 accepted and v2 answers with a
400. `GOTOOLCHAIN=go1.27.1 ./verify.sh` exits 0 over **79 gates**, the same count as
v4.4.0; `GOTOOLCHAIN=go1.27.1 make ci` is green on `ede246d` with `go version go1.27.1
darwin/arm64` on the line after the echoed recipe — run after the commit, because `ci`
archives HEAD and a run before the commit had proved the old tree. The seven other
top-level Go modules on this machine sit on `go 1.26` or older with 177 files importing
v1 between them, and a nested one under `kai` adds seven more; none can import v2 until
its pin moves, so their move is the next re-scan's, and any of them that tags a `-json`
or wire contract moves it at its next major, as the ruling says.

### 2026-09-05 — the pin moves a major (v4.4.0)

**Go 1.27.1 shipped on 2026-09-01, and the policy adopts a major at its first patch.**
[VERSIONS.md](VERSIONS.md) pins 1.27.1; the `go.mod` line is `go 1.27` in the three
checklists, [stack/go.md](stack/go.md), and [operations/ci.md](operations/ci.md); every
`GOTOOLCHAIN=go1.26.7` in the corpus is `go1.27.1`; and `git grep '1\.26'` outside this
file hits one historical clause in the Go row. Not a security release; the row says so and
stops there, because what a patch fixed is this file's to record, not the pin table's:
1.27.1 fixes 1.27.0's `go fix` — its new `embedlit` fixer emitted code that did not
compile (go.dev/issue/81006, 81059, 81101), so the "read that diff before you commit it"
bullet in ci.md now has a case number behind it — `encoding/json` rejecting a quoted
`null` on a `string` field under `,string` (81083), and `Request.Body.Close` returning
`io.EOF` on a body read only partway (81027). 1.27.0 is the floor the row names: every
advisory of 2026-08-13 is fixed from 1.27.0-rc.3, GO-2026-6091 — the `html/template`
unescaped `/`, XSS — included, which is what keeps the pin tier 1 under README's own
definition. 1.27.0 and 1.27.1 register the same 26 fixers, diffed; `make fmt` under the
new pin rewrote nothing in the reference — its `errors.As(err, new(*T))` inside a
`switch` case is a shape `errorsastype` leaves alone — so this release has no rewrite
commit. Two of the four other baseline repositories on this machine would not be so lucky:
`go fix -diff` under 1.27.1 wants seven files in one and two in another, which is the
re-scan the maintenance protocol schedules and this run did not do for them.

**The six questions the 2026-08-25 entry left for this pass, each answered by running
it.** `httptest.NewTestServer` inside a bubble works: a handler that slept an hour on the
bubble clock answered at once, `synctest.Wait` settled, and a goroutine the handler
started ran when `synctest.Sleep(10 * time.Minute)` moved the clock; a real
`httptest.NewServer` in the same bubble serves a plain request and hangs the moment the
bubble's clock or `Wait` is involved, with a goroutine in `net.(*conn).Read`. Go's own doc
now says most users should use `NewTestServer`, so
[go-testing.md](patterns/go-testing.md)'s handler-test snippet is the in-memory server and
its `Client()` — the only client that reaches it; `srv.URL` is empty until that first
call — and [go-background-work.md](patterns/go-background-work.md) keeps its two-item
list and points there. Client tests keep the real socket, except a timeout test, which
builds the `Client` struct around `srv.Client()` inside the bubble: `Client.Timeout` and
`ResponseHeaderTimeout` both fire on the bubble clock, verified. `synctest.Sleep` is one
clause in go-testing.md. `Server.MaxHeaderValueCount` defaults to 500
(`DefaultMaxHeaderValueCount`) and stays unset beside `MaxHeaderBytes`: one bullet in
[go-http-server.md](patterns/go-http-server.md) says so, so nobody tunes it. `go test`
running `stdversion` needs no rule — it fires on a symbol newer than the `go` line,
which a `go 1.27` module on the 1.27 pin cannot write, and the Test gate carries it. `go
mod tidy` merging `require` blocks moved nothing; the reference has two. **`encoding/json`
stays v1.** v1 is backed by v2 since 1.27.0, so the parser and the speed are shared; the
v2 API was three weeks stable with two fixes in 1.27.1 (81012, and 81083 on the v1
surface); and v2's stricter defaults — duplicate names and invalid UTF-8 rejected —
are the one thing v1 lacks, which matters at `/api` input and is exactly why adopting it
is a rewrite of every JSON fence and both of the reference's machine surfaces, a change of
its own. It is a decision Andy makes, and it is on the list he was handed.

**What the release absorbed, which is the question README's maintenance protocol asks.**
Two things. `uuid` is standard library: a row in *Modern stdlib choices*, and no row left
*Approved third-party dependencies*, because `google/uuid` was never on it (it sits in the
reference as an indirect of `modernc.org/sqlite`). And `Response.Body.Close` now drains up
to 256 KiB (`maxPostCloseReadBytes` in `net/http/transport.go`) before closing, so the
connection goes back to the pool — which is what the `drainAndClose` helper in
[go-http-client.md](patterns/go-http-client.md) did by hand with a 4 KiB cap. The helper
is gone, rule 3 is `defer resp.Body.Close()` and says exactly what the transport does, the
two documents that named the helper stopped, and the reference lost its copy. The exact
part cost a round: the first sentence said `Close` drains "first" and the connection "goes
back to the pool"; measured with `httptrace`, `Close` returns in microseconds and the read
loop drains afterwards, only when the declared length is at most 256 KiB or unknown,
giving up after 50 ms — a longer or stalled body costs the connection, which is what the
old 4 KiB helper cost too.

**htmx 4.x was a beta in two documents and is not.** [stack/htmx.md](stack/htmx.md) still
said "in beta"; every web application reads it, so the floor contradicted VERSIONS.md
until the first pass caught it. The tier-1 rationale was another: a rewrite of
[stack/go.md](stack/go.md)'s "its note names a security fix" broke README's own tier-1
definition, so the sentence is back and the Go row names the floor and what GO-2026-6091
is — the definition, not the release, is what makes the pin tier 1.

**Facts re-measured under 1.27.1, all holding.** The 307 on a slash-only route in
[go-authorization.md](patterns/go-authorization.md); the two source claims in
[go-file-uploads.md](patterns/go-file-uploads.md), whose links moved to the go1.27.1 tag
and whose wording tightened — `parsePostForm`'s multipart case is *empty*, not absent;
`.webmanifest` → `""` and `.woff2` → `font/woff2` on this Mac, in
[pwa.md](patterns/pwa.md) and [css-typography.md](patterns/css-typography.md). Two
adjudications, made out loud because reviewers split on them across passes. The three
*Facts verified* headings moved to this date because every bullet under them — the
webstatus.dev statuses, the MDN and WHATWG pages, the browser-compat data, not only the Go
lines — was read at its source again; two tightened on the way: `ServeContent`'s quote
now matches the 1.27.1 doc, and `mime/type_unix.go` reads shared-mime-info's `globs2`
before the four `/etc` files. The stamps of two of those documents stayed, because a
re-measured fact is not a reviewed rule; [pwa.md](patterns/pwa.md)'s moved, because its
rule's mechanism sentence was corrected from the source. And
[go-authorization.md](patterns/go-authorization.md)'s stamp moved on a one-token edit: the
file carries a "(307 on Go 1.27)" claim and has no *Facts verified* heading, so the stamp
is the only date that can carry a release the old stamp predates. A stamp that says
2026-08-17 over a Go 1.27 fact is the contradiction a reader sees; the rule about wording
edits is for edits that change no claim.

**htmx 4.0.0 shipped stable on 2026-08-28**, on npm's `next` tag while `latest` still
names 2.0.10. The row stopped calling it a beta and says what adoption would be — a
change of its own. Every other row was read at its source on the day: htmx 2.0.10, scs
v2.9.0, `design.md` still `alpha` with its CLI at 0.4.0.

**What "re-verify after a Go major" meant here, said so it is not re-litigated.** The
release notes were read against every rule — that is the walk README's protocol asks
for, and it is how six features found their documents and `uuid` found the table. A stamp
moved only where a rule, or the mechanism sentence under it, was re-derived against
1.27.1; thirty documents whose rules 1.27 does not touch keep their August stamps, because
a stamp is a claim that the rules were reviewed, and moving them would claim a review that
did not happen. Their 90-day clocks run from those dates; the next full cycle is due in
November. htmx 4.0.0 fired the same clause: the pin did not move, so the htmx documents
were read for what 4.x changes about their rules — nothing, while 2.x is the pin — and
only [stack/htmx.md](stack/htmx.md), whose warning was false, moved.

**The budgets held, and the change path came back 44 tokens lighter.** The Go row lost the
three issue numbers a pass judged to be this file's, and VERSIONS.md ended 176 bytes
shorter: the change path is 7,965 → 7,923 of 8,000, the floor 20,228 → 20,304, the web
checklist unchanged at 4,986. One document is at its cap:
[go-http-client.md](patterns/go-http-client.md) stands at 3,796 of 3,800 after the drain
rule and the in-memory testing bullet, so the next sentence added there pays for itself or
the document is split. (README says a document "stays under 3,800" and the Makefile fails
only above it — at exactly 3,800 the two disagree; noted, not settled here.) The branch
stands: the next trigger section needs the shape-budget decision, not a version row's
leftovers.

**Sixty-nine findings over sixteen passes, two lenses each — facts by execution, writing
against STYLE.md — the last two clean on both.** Nineteen, nine, ten, seven, three, two,
five, two, three, three, two, one, one, two, two, one, one, two, then nothing twice. The
first pass found the contradictions: [stack/htmx.md](stack/htmx.md) still calling 4.x a
beta on the floor path; a tier-1 rationale rewritten out from under README's definition; a
`Close` sentence that said "first" and "goes back to the pool" where the transport drains
afterwards, only up to 256 KiB, and only within 50 ms; "a real listener never can" where a
plain request through one works and only the bubble's clock and `Wait` hang; and
`errors.As` still in the table the `go fix` gate now rewrites. The second pass was
sentences saying more or less than the tool does — the drain rule over HTTP/2 costs a
stream, not the connection; 81083 was a rejection, not a misread; "hang on it" reads as
"depend on"; the socket rule stated in two documents, each citing the other as owner; and
"a change of its own", which compares against a change the reader of stack/go.md never
sees. The third was referents: "it" binding to the `Client` struct, which has no timeout
field; a `Wait` that could be the app's own; a drain rule that measured the declared
length for one body shape and the unread remainder for the other — the exact form gates
on the whole body only when a `Content-Length` is declared; and status detail (a version,
a date, a fixer's name) sitting in rules documents where README sends it here. The fourth
was the rewrite's own wake: an em-dash substitution that put the 50 ms clock on the whole
body, where the transport times only the unread rest; "the default client" blaming a
client the reader no longer holds; a Go 1.27 fact under a stamp older than Go 1.27; a rule
still saying "merges" beside a fact rewritten to a priority lookup; and the one Go 1.27
feature without its `(Go 1.27+)` mark. The fifth found the facts lens clean and three on
the writing side, one of them the trim this entry's budget paragraph reports: three
upstream issue numbers in the pin row were what the run found, which is this file's to
hold, and the row lost them. The sixth: `errors.As` had left the table's "Use" column
without arriving in "Instead of" — the absence defect, a decision visible only in the
diff — and one comment said "host" in two roles. The seventh: the same "merges" still
stood in css-typography.md's sibling rule; `errors.As` in the do-not-use column overstated
Go's own "for most uses, prefer AsType" — a target interface without `Error()` cannot go
through `AsType[E error]`, and 1.27.1's `errorsastype` fixer still rewrites that shape
into code that does not compile (go.dev/issue/80031, fixed upstream after 1.27.0), so the
cell names the exception and ci.md's per-fixer switch is the escape; a socket rule written
as a description where its owner should state it as a rule; an appositive that made the
adoption the breaking change; and one "and" where the relation is contrast. Two more were
raised and not taken, recorded above: the facts headings and the authorization stamp. The
eighth: "set the timeouts on that `*http.Client`" in the one document whose subject is
which timeout lives where — `ResponseHeaderTimeout` is the transport's — and an
imperative with no subject in the htmx row; both paid for by two flourishes, since the
client document stood one token under its cap. The ninth: "in its own package" heard as *a
package of its own*, the opposite of the white-box test it meant; and two points of
protocol — the rules commit had no *Owed* entry where every one before it carried one,
and the clause "always after a major release of Go or htmx" had fired with thirty stamps
unmoved, which is the scoping adjudicated below. The tenth found the rules documents clean
and three in the new *Owed* paragraph itself: a count the list could not reproduce, the
two promised rulings that needed no rule left unsaid, and "two documents that named it"
where only one had. The eleventh, two more in that paragraph: a ruling it had not placed,
and two folded into one. The twelfth and thirteenth, one each in that paragraph: a line
three columns past the wrap, and a list that ran one item too long. The fourteenth, two:
an "It" twelve lines from its subject, and two changes the paragraph had not placed. Every
mechanical claim was executed rather than read: the drain matrix over fixed, chunked,
stalled, and HTTP/2 bodies with `httptrace`; the in-memory server and both client timeouts
on the bubble clock; the real socket in a bubble, hanging and not; the fixer on
`errors.As`; the `go 1.28` refusal under the pin; every advisory of 2026-08-13 against its
fixed range; and the four client fences through every gate in a scaffold.

**This machine.** The shell profile's `GOTOOLCHAIN` moved with the pin, as the 2026-08-27
entry said it would have to, and the three tool binaries in `~/bin` were rebuilt with
1.27.1 — the ones built with 1.26 refuse 1.27's standard library. Homebrew's Go is
1.27.1, so pin and machine agree for the first time since 2026-08-19. `baseline-ops` moved
its build image to `golang:1.27-alpine` in the same sitting: the official image sets
`GOTOOLCHAIN=local`, so a `go 1.27` module on the 1.26 image would not have built.

**The empirical half:**
[baseline-reference](https://github.com/andygeiss/baseline-reference) `4d1ea3f`, tagged
v4.4.0, pinning baseline `ce86f13`. `GOTOOLCHAIN=go1.27.1 ./verify.sh` exits 0 over **79
gates**, one more than v4.3.0: the `go` line of `go.mod` is the pin's major and no
`toolchain` line follows it, run red on both before it was trusted. `GOTOOLCHAIN=go1.27.1
make ci` is green on `4d1ea3f` with `go version go1.27.1 darwin/arm64` as its first line.
What moved: `go.mod` to `go 1.27`; `internal/anthropic` lost its drain helper; the
handler-test harness onto `httptest.NewTestServer` — its `Client()` carries the jar and
the redirect stop, the API tests' bare client shares its transport, and every handler test
(cookies, redirects, htmx headers, uploads) passed on the in-memory network at the first
run; the README's stack line; and four dependencies under the pin as their own
`chore(deps)` commit — `golang.org/x/crypto` v0.56.0, `modernc.org/sqlite` v1.58.0 with
`libc` v1.75.7 and `memory` v1.12.1. `govulncheck` reports no reachable vulnerability and
one informational entry in a required module the code never calls (GO-2026-5932,
`golang.org/x/crypto`).

### 2026-09-04 — no code before the brief (v4.3.0)

**The checklists guard the end of a task; nothing guarded the start.** A task that
arrives as one sentence gets finished by guessing, and every guess is a decision the
reader never made. Every task now carries four fields the user has seen before the
first line of code — job, why, guardrails, done means — drafted by the agent from the
request, the repository, and the project's `SPEC.md`, asked about one question at a
time with a recommended answer, and re-read as the acceptance test before done.
[SKILL.md](SKILL.md) *Before the first line of code* is the rule; [README.md](README.md)
*The task brief* is the definition behind it, the same split the tiers have. `SPEC.md`
at every project's root is the project-level brief, and a task brief is a delta against
it: a row in each project-type table, a line in the two layout trees, a box in every
checklist's *Every …* section beside the two that make the brief the acceptance test.

**Where the rule had to live was the first defect, and the design review caught it.**
The draft put the whole rule in README with a pointer in SKILL.md, the way the waiver
form is reached. The waiver pointer fires at a rare moment; the brief fires on every
task, so README would have become a per-task read that four sentences say never happens
and `make tokens` never counts. The operative rule moved into SKILL.md with the four
one-line fields, README kept the survival table, the `SPEC.md` shape, and the example,
and the project-type row carries the shape itself so nothing on the floor path opens
README. Two more from the same review: `DESIGN.md` and `PATTERNS.md` left the survival
table — the first holds token values, not reasons; the second does not exist — and the
full-interview trigger reuses SKILL.md's shape line instead of "touches more than one
package", which in this layout fires on nearly every feature.

**The budgets held by trimming, which was the branch the 2026-08-18 entry left open.**
The web checklist had five tokens and the change path sixty-one; the section, the boxes,
and the trigger cost about a hundred and thirty. Fourteen rationale sentences left
`SKILL.md` — every one a second sentence for a rule whose instruction survives on the
line before it, and one a verbatim restatement of core value 6 — and four lines left the
web checklist, one of them the thumbnail cross-reference that `go-file-uploads.md` makes
itself. `SKILL.md` still ends 35 tokens larger (1,763 → 1,798), the checklist 9 smaller
(4,995 → 4,986), and the change path moved 7,939 → 7,965 of 8,000; the floor is 20,227.
Thirty-five tokens of headroom is not room for the next trigger section, which is what
*What would make these numbers wrong* under that entry says comes next: the shape
budget, not a third raise.

**Sixty-three defects over seven passes, two lenses each round; passes eight and nine
clean on both.** Thirty-two, nine, five, eight, five, three, one, then nothing. The
first pass found the structural ones: an agent inside an existing project never reaches
the README section that says how to write a missing `SPEC.md`, "confirmed" contradicted
the decline clause, the fourth field was "Done" in the rows and "Done means" everywhere
else, and the reference gate would have rejected the format the README's own example
uses. After that every defect was a sentence saying more or less than it meant — "the
sections below are the long form" when one bullet's long form is above it; "links" where
the corpus and the reference both name; a gate anchored at column one that failed a
bulleted label with a message calling the label absent. One defect sat outside the diff
and was fixed with it: the README tree still labelled README the "navigation protocol",
the claim README.md:30 retired.

**The empirical half:**
[baseline-reference](https://github.com/andygeiss/baseline-reference) `883dcb8`, tagged
v4.3.0, pinning baseline `7c5c2a4`. `SPEC.md` carries the four fields under *The brief*,
each bullet naming its long form, and a fifth acceptance criterion, `make ci`;
`verify.sh` gates the file and the four labels as its ninth step, accepting a bold
name or a `Field:` line and rejecting a heading, and was run red on a missing file, a
missing field, and a renamed one before it was trusted. `GOTOOLCHAIN=go1.26.7 ./verify.sh`
exits 0 over **78 gates**, one more than v4.2.0, and `GOTOOLCHAIN=go1.26.7 make ci` is
green on `883dcb8` with `go version go1.26.7 darwin/arm64` as its first line. No code
moved; nothing needed a waiver.

### Earlier runs

Compressed to what a future reader still needs: the counts, and the findings that would
otherwise be re-litigated. The full narratives are in this file's git history.

**The three newest runs stay in full; everything older lives here.** A run log that only
grows costs more to re-read than it saves, and the compression is what keeps a narrative
from being re-litigated a year after it was settled.

- **2026-08-27 — go fix joins the gates (v4.2.0).** 27 defects over seven rounds, the
  last two clean. `go fix -diff` is the third line of `check` and `go fix ./...` the
  last of `fmt`, after `goimports`, because `go fix` type-checks and stops on a missing
  import. **The fixer set is the toolchain's:** 1.26.0–1.26.7 register the same 22,
  1.27.0 registers 26, so the gate is deterministic only under an exact `GOTOOLCHAIN`,
  and the escape is `-<fixer>=false` on both lines in the commit that says why — a flag
  name the next major may drop. Two conflicting fixes exit non-zero with an empty diff
  (go.dev/issue/77482, 80854); generated files are skipped, and a file behind a build
  tag the command was not given is never seen. The `any` rule left stack/go.md;
  `new(expr)` stays, worded so the removal of an inlined helper is the reader's and the
  library case is go-library.md's (an exported one is a major there). Change path
  unchanged at 7,939; floor 20,097. Reference `6ea52e6`, v4.2.0, pinning `6015026`: 77
  gates; four files of code moved — two the pin rewrote, two `errors.As` sites moved to
  `AsType` by hand.

- **2026-08-25 — gaps flow back from projects (v4.1.0).** The corpus could learn from
  projects and had no way to hear about it: `SKILL.md` *Handing the work back* now takes a
  decision the checklist had no section for as a next step, and `README.md` *Maintenance
  protocol* asks at every Go major what the release absorbed. **The rule's failure mode is
  noise, so the bar is the whole design:** two kinds qualify, "this looked reusable" is
  named and excluded, and it was tested against a real gap (inbound webhooks) and a real
  false one (CSV downloads, boxes under *Taking a file from a user*). Absorption is a
  rewrite, not a retirement, said where retirement is decided. Nine defects over ten
  passes, the last two clean, plus two caught in the entry as it was written — the
  interesting ones arithmetic, every one a number carried over from a draft instead of
  re-derived. `SKILL.md` grew 116, 380 since the raise; the change path reached 7,939 of
  8,000 and the floor 20,089: trim, do not raise. One defect found and left: "nothing else
  qualifies" could be read to scope out the collision rule — different mechanism,
  different timing, and the joining clause would have cost 15 of the last 61 tokens.
  Reference `6239e4e` tagged v4.1.0, pinning `99a94e0`; `SPEC.md` the only file that
  moved, because both rules govern what an agent reports, which no repository can gate;
  `./verify.sh` exit 0 over 76 gates.

- **2026-08-25 — the CI server dropped (v4.0.0).** No CI server anywhere in the corpus:
  `make check` gates the working tree and `make ci` the commit — `git archive HEAD` into
  an empty directory, then the same `check`, so nothing missing from `git add` and no
  `.env` can make it green; the scan of untouched code and the toolchain moved to a
  person on the 90-day cycle ([operations/ci.md](operations/ci.md)). **The `ci` recipe was
  wrong twice before it was right, and only running it said so:** a piped
  `git archive | tar` reports the pipe's status, so a failed archive still ran the gates
  against an empty directory (the file form exits 128 where the pipe exits 0), and
  `go version` outside the copy resolves `GOTOOLCHAIN` against the working tree's
  `go.mod`, so it runs inside the copy as `go -C "$d" version`. Settled by execution:
  under `GOTOOLCHAIN=go1.26.7`, `go get` refuses a `go 1.27` module and leaves the file
  alone; under `auto` it prints one line and raises it; `go mod tidy` raises it with no
  output at all; `go mod edit` never reads the graph; a module cache is read-only, so
  `go clean -modcache` is the line. **The defect class named is the absent file:** the
  reference gates nothing under `.github/workflows/`, no `dependabot.yml`, and no
  `export-ignore` in `.gitattributes` — `git archive` honours it and the go command does
  not — plus targets alphabetical and `check` as `.DEFAULT_GOAL`. The web checklist went
  8 over and was paid, not moved (4,995). Eleven defects in the closing rounds, the last
  two clean, one of them this repository's own `Makefile` lacking `.DEFAULT_GOAL`.
  Reference `9edcd6a` tagged v4.0.0, pinning `7703305`, `./verify.sh` exit 0 over 76
  gates; module path `/v3` → `/v4`, because a v4 tag on a `/v3` module never stamps.

- **2026-08-25 — the pins, checked against their sources (v3.11.1).** Every numbered
  row in [VERSIONS.md](VERSIONS.md) read against its own source on the day, not only the
  one that moved. **Go moved twice in one day and the policy answered both:** 1.26.7 is
  the pin (*always the latest patch*), a point release that restores unencrypted HTTP/2
  after 1.26.6's `net/http` fix (go.dev/issue/80876) — nothing in the corpus, the
  reference, or `baseline-ops` enables h2c; 1.27.0 is not adopted (*a major at its first
  patch*), so 1.27.1 is the trigger. htmx 2.0.10, scs v2.9.0, the two `actions/*` at v7
  on node24, and `design.md` still `alpha` while its CLI tags 0.4.0 — all confirmed at the
  source. Nothing downstream needed a commit: the reference's `go.mod` says `go 1.26`
  with no toolchain line and the ops Dockerfile floats on `golang:1.26-alpine`. The one
  place that did was this machine, where Homebrew's Go is 1.27.0 and the `govulncheck`
  binary built with 1.26 refuses 1.27's standard library — so **every local run is pinned
  with `GOTOOLCHAIN=go1.26.7`** until 1.27.1. What 1.27.1 will ask, written down for the
  adoption pass: `httptest.NewTestServer` gives a `synctest` bubble an in-memory network
  (the listener-outside-the-bubble constraint in
  [go-background-work.md](patterns/go-background-work.md)); `synctest.Sleep`;
  `Server.MaxHeaderValueCount` for [go-http-server.md](patterns/go-http-server.md) to rule
  on; `go test` running `stdversion` by default; `go mod tidy` merging `require` blocks
  under `go 1.27`; and `encoding/json/v2`. Reference `bb315d5` tagged v3.11.1, pinning
  `b342f17`, `./verify.sh` exit 0 over 74 gates; `govulncheck` found one informational
  entry in a required module never imported (GO-2026-5932). No document stamp moved but
  the pin line.

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
