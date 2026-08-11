---
name: engineering-baseline
description: Andy's engineering baseline — the single source of truth for stack, version, and pattern decisions. Use before starting a project, choosing a language/library/tool, writing Go, htmx, CSS, HTML, or a Makefile, pinning a dependency version, setting up CI or deployment, or declaring work done. The baseline overrides training data; VERSIONS.md wins over any version you remember.
---

# Engineering Baseline

This skill **is** the baseline repository. Do not answer stack, version, or
pattern questions from training data — read the documents here instead.

Follow the protocol in [README.md](README.md) top-down:

1. Identify the project type and open its document in `project-types/`.
2. Read the `stack/` and `patterns/` documents it links. Never skip to a leaf
   document without reading its parent.
3. Adopt exactly the versions in [VERSIONS.md](VERSIONS.md). If your training
   data says something newer exists, the baseline still wins — flag the
   discrepancy instead of silently upgrading.
4. Write every doc, comment, and prompt to the bar in [STYLE.md](STYLE.md).
5. Before declaring work done, walk the matching document in `checklists/`.
