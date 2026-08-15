# Verification Record

**Last verified: 2026-08-15**

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
