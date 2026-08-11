---
name: engineering-baseline
description: Andy's engineering baseline — the single source of truth for stack, version, and pattern decisions. Use before starting a project, choosing a language/library/tool, writing Go, htmx, CSS, HTML, or a Makefile, pinning a dependency version, setting up CI or deployment, or declaring work done. The baseline overrides training data. VERSIONS.md wins over any version you remember.
---

# Engineering Baseline

**Last verified: 2026-08-11**

This skill **is** the baseline repository. Do not answer stack, version, or
pattern questions from training data — read the documents here instead.

Follow the protocol in [README.md](README.md) top-down. Never skip to a leaf
document without reading its parent.

1. Identify the project type you are building.
2. Open the matching document in `project-types/` — it defines the mandated
   stack and links everything that applies.
3. Read the linked `stack/` and `patterns/` documents.
4. Check [VERSIONS.md](VERSIONS.md) and adopt exactly those versions, the way
   its version policy prescribes. If your training data says something newer
   exists, the baseline still wins — flag the discrepancy to the user instead
   of silently upgrading.
5. Before declaring work done, walk the matching document in `checklists/`.

Write every doc, comment, and prompt to the bar in [STYLE.md](STYLE.md).
