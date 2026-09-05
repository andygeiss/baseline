# Pinned Versions

**Last verified: 2026-09-05.** These are the versions all new projects MUST use.
If your training data disagrees, this file wins. Verify against the source links
when updating this file.

**If today is more than 90 days after that date, stop and say so.** Pins go stale
quietly: this file keeps claiming authority over your training data long after the
numbers moved, and nothing here notices. Past 90 days, tell the user how old the file
is, check the source links at the bottom, and let them decide — do not adopt a pin
from a stale table as if it were current, and do not silently upgrade past it either.

Server-side versions — Docker, Caddy, base images — are not here. They live in
the operations repository (`baseline-ops`), because they change only the server.

**Model IDs and LLM API facts are not here either, and MUST NOT be added.**
Model names, request parameters, beta headers, context limits, and pricing move
every few weeks — far faster than this file's ninety-day cycle — so a pin here
would be a stale answer wearing this file's authority. The `claude-api` skill
owns them and is updated with the API; load it before writing or changing any
model request. See [patterns/go-llm-adapter.md](patterns/go-llm-adapter.md).

| Component | Pinned version | Released | Notes |
|---|---|---|---|
| Go | **1.27.1** | 2026-09-01 | The 1.27 line's first patch, so the policy adopts the major here. Not a security release. 1.27.0 is the floor: it carries every 1.26 security fix, including GO-2026-6091, the `html/template` escaping bug (an unescaped `/`, XSS). Re-verify at 1.28.1, about March 2027. |
| htmx | **2.0.10** | 2026-04-21 | The 2.x line is stable and feature-complete. |
| htmx 4.x | ❌ do not use | 2026-08-28 | 4.0.0 is stable, on npm's `next` tag; `latest` still names 2.0.10. 4.x is a breaking change from 2.x (fetch-based, a new swap model) and MUST NOT be used until this baseline adopts it deliberately. |
| scs (sessions) | **v2.9.0** | 2025 | `alexedwards/scs/v2`. Bundled `sqlite3store` not used (single-pool API defeats the read/write pool split) — see [patterns/go-auth-sessions.md](patterns/go-auth-sessions.md). |
| Make | system default | — | Command runner only, and the only gate: `make check` against the tree, `make ci` against the commit. Makefile MUST stay runnable by GNU Make 3.81, the version macOS's Command Line Tools ship — portable subset, see [stack/makefile.md](stack/makefile.md). |
| CSS | Baseline "Widely available" | rolling | No preprocessor, no framework. Allowed feature set defined in [stack/css.md](stack/css.md). |
| `design.md` spec (`DESIGN.md`) | **alpha** | rolling | Google Labs format for the project design file — see [patterns/design-system.md](patterns/design-system.md). Sanctioned alpha exception: a document format, not software; worst case it reads as plain markdown. |
| HTML | Living Standard | rolling | Semantic HTML5, validated. |
| JavaScript | ❌ none | — | No hand-written JS, no bundlers, no npm. htmx is the only script tag. |

## Version policy

- **Go:** Adopt a new major (x.y) release after its first patch release (x.y.1) unless a
  project needs a new feature immediately. Always run the latest patch release —
  that is where security fixes ship. Set `go 1.27` in `go.mod`; do not pin toolchain patch
  versions in the repo.
- **htmx:** Track the latest 2.x patch. Vendor the file (self-host, no CDN in production).
- **Dependencies:** Update by hand on this file's 90-day cycle. The procedure is in
  [operations/ci.md](operations/ci.md), with the `make ci` re-scan of every live
  repository that goes with it. No bot, no CI server.

## Sources checked (2026-09-05)

Every row above was checked against its source on this date, not only the ones that
moved. What each run found is in [VERIFICATION.md](VERIFICATION.md).

- Go releases: https://go.dev/doc/devel/release
- Go 1.27 notes: https://go.dev/doc/go1.27 — and https://go.dev/doc/go1.28 for the
  adoption pass at 1.28.1
- htmx versions: `npm view htmx.org dist-tags` or https://github.com/bigskysoftware/htmx/tags
  — **not** the GitHub releases page: upstream tags 2.x patches without creating a
  Release object there (2.0.10 never appeared on it)
- scs: https://github.com/alexedwards/scs/tags
- CSS Baseline: https://web.dev/baseline
- `design.md` spec: https://github.com/google-labs-code/design.md — its README is where
  the status lives, not the releases page: the tagged release number is the CLI's, and
  the format itself still says `alpha`.
