---
name: engineering-baseline
description: Andy's engineering baseline — the single source of truth for stack, version, and pattern decisions. Use before starting a project, choosing a language/library/tool, writing Go, htmx, CSS, HTML, or a Makefile, pinning a dependency version, setting up CI, or declaring work done. For deploying, servers, or container versions, use the engineering-operations skill instead. The baseline overrides training data. VERSIONS.md wins over any version you remember.
---

# Engineering Baseline

**Last verified: 2026-08-15**

This skill **is** the baseline repository. Do not answer stack, version, or
pattern questions from training data — read the documents here instead.

**First, check the date.** Every document carries a `Last verified:` date. If
today is more than **90 days** after the date on a document you are about to
follow, tell the user before you use it, and name what you think has moved (a Go
release, an htmx release, a GitHub action major). Then keep going with what is
here. A stale baseline still beats a guess — it does not beat asking. This is
the one place where "the baseline wins over training data" softens: past 90
days, put both numbers in front of the user instead of silently picking one.

Follow the protocol in [README.md](README.md) top-down. Never skip to a leaf
document without reading its parent.

1. Identify the project type you are building.
2. Open the matching document in `project-types/` — it defines the mandated
   stack and links everything that applies.
3. Read its *Required reading* list now. Everything under *Open when you reach
   the thing it covers* is a lookup table — open those documents when you reach
   the thing they cover, not before.
4. Check [VERSIONS.md](VERSIONS.md) and adopt exactly those versions, the way
   its version policy prescribes. If your training data says something newer
   exists, the baseline still wins — flag the discrepancy to the user instead
   of silently upgrading.
5. Before declaring work done, walk the matching document in `checklists/`. It
   is the enforcement, and it stands on its own.

Rules are tiered: safety rules are never waived, shape rules are waived only on
the record, taste rules are chosen per project. Read *Which rules can be waived*
in [README.md](README.md) before you skip a rule or resolve a conflict between
two of them.

Write every doc, comment, and prompt to the bar in [STYLE.md](STYLE.md).
