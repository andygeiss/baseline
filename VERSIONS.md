# Pinned Versions

**Last verified: 2026-08-17.** These are the versions all new projects MUST use.
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
| Go | **1.26.6** | 2026-08-13 | Latest stable patch of the 1.26 line. Security release: fixes GO-2026-6089/6090/6091/5972, including an `html/template` JavaScript-context bug that reaches every rendering app. Go 1.27 expected Aug 2026, and not out on 2026-08-17 — re-verify after release. |
| htmx | **2.0.10** | 2026-04-21 | The 2.x line is stable and feature-complete. |
| htmx 4.x | ❌ do not use | beta | 4.0.0-beta6 (July 2026). MUST NOT be used until stable *and* adopted here deliberately (breaking changes: fetch-based, new swap model). |
| scs (sessions) | **v2.9.0** | 2025 | `alexedwards/scs/v2`. Bundled `sqlite3store` not used (single-pool API defeats the read/write pool split) — see [patterns/go-auth-sessions.md](patterns/go-auth-sessions.md). |
| `actions/checkout` | **v7** | 2026-07 | Pinned by major only; Dependabot bumps the patch. Node 24 runtime (v5 was the first). v7 blocks checking out fork PR heads under `pull_request_target`/`workflow_run` — the sanctioned workflows use neither. |
| `actions/setup-go` | **v7** | 2026-07 | Pinned by major only. Node 24 runtime (v6 was the first). v6 also exports `GOTOOLCHAIN=local` — see [operations/ci.md](operations/ci.md). |
| Make | system default | — | Command runner only (`make check` = CI). Makefile MUST stay runnable by macOS's bundled GNU Make 3.81 — portable subset, see [stack/makefile.md](stack/makefile.md). |
| CSS | Baseline "Widely available" | rolling | No preprocessor, no framework. Allowed feature set defined in [stack/css.md](stack/css.md). |
| `design.md` spec (`DESIGN.md`) | **alpha** | rolling | Google Labs format for the project design file — see [patterns/design-system.md](patterns/design-system.md). Sanctioned alpha exception: a document format, not software; worst case it reads as plain markdown. |
| HTML | Living Standard | rolling | Semantic HTML5, validated. |
| JavaScript | ❌ none | — | No hand-written JS, no bundlers, no npm. htmx is the only script tag. |

## Version policy

- **Go:** Adopt a new major (x.y) release after its first patch release (x.y.1) unless a
  project needs a new feature immediately. Always run the latest patch release —
  patches are security fixes. Set `go 1.26` in `go.mod`; do not pin toolchain patch
  versions in the repo.
- **htmx:** Track the latest 2.x patch. Vendor the file (self-host, no CDN in production).
- **GitHub Actions:** Pin the major tag only (`@v7`), never a floating branch and never
  a version older than the current major. Run every action on a **supported Node
  runtime** — GitHub deprecates the old one long before it removes it, and a
  deprecation annotation on a green run is the signal to bump, not a warning to ignore.
  Verify the current major against the action's tags before editing this table; the
  numbers move faster than any training data.
- **Dependencies:** Updated weekly by Renovate/Dependabot in one grouped PR, merged on
  green CI (the mechanism lives in [operations/ci.md](operations/ci.md)). Anything that
  breaks on a routine update is a candidate for removal.

## Sources checked (2026-08-17)

Every row above was checked against its source on this date, not just the ones that
moved. Nothing moved: the only edit was Go 1.26.6's release date, which this table had
as 2026-08-11 and the release history gives as 2026-08-13.

- Go releases: https://go.dev/doc/devel/release
- Go 1.26 notes: https://go.dev/doc/go1.26
- htmx versions: `npm view htmx.org version` or https://github.com/bigskysoftware/htmx/tags —
  **not** the GitHub releases page: upstream tags 2.x patches without creating a
  Release object there (2.0.10 never appeared on it)
- CSS Baseline: https://web.dev/baseline
- GitHub Actions majors: https://github.com/actions/checkout/tags and
  https://github.com/actions/setup-go/tags — the `using:` line in each action's
  `action.yml` is the authoritative Node runtime
- `design.md` spec: https://github.com/google-labs-code/design.md — its README is where
  the status lives, not the releases page: tagged releases reached 0.4.0 (2026-07-27)
  while the format itself still says "The DESIGN.md format is at version `alpha`". The
  release number is the CLI's, so it is not evidence the format settled.
