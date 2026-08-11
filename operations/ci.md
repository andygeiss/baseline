# Operations: CI

**Last verified: 2026-08-10**

The [checklists](../checklists/)' mechanical items run on every push —
a human never checks what a machine can. Copy this workflow into new projects verbatim
(`.github/workflows/ci.yml`):

```yaml
name: ci
on:
  push: {branches: [main]}
  pull_request:
  schedule:
    - cron: "0 6 * * 1"   # weekly: catches new CVEs in unchanged code

permissions:
  contents: read

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod   # single source of truth for the Go version
          check-latest: true        # newest patch release = current security fixes

      - name: Format
        run: test -z "$(gofmt -l .)" || (gofmt -l . && exit 1)

      - name: Vet
        run: go vet ./...

      - name: Staticcheck
        run: go run honnef.co/go/tools/cmd/staticcheck@latest ./...

      - name: Vulncheck
        run: go run golang.org/x/vuln/cmd/govulncheck@latest ./...

      - name: Tidy
        run: go mod tidy -diff

      - name: Test
        run: go test -race -shuffle=on ./...

      - name: Build (static)
        run: CGO_ENABLED=0 go build -trimpath ./...
```

## Why each gate exists

- **`go-version-file` + `check-latest`** — CI always tests on the latest patch of the
  module's Go version; patch releases are security releases.
- **`govulncheck`** — call-graph-aware CVE scanning; the `schedule` trigger re-scans
  weekly so a vulnerability disclosed *after* your last push still pages you. A red
  weekly run means: bump the dependency, don't silence the check.
  ⚠️ GitHub disables scheduled workflows in public repos after 60 days without
  repository activity — silently, with no red run. The weekly Renovate PR (below)
  normally provides that activity; if a repo goes quiet anyway, re-enable the
  workflow (Actions → ci → Enable) or expect no weekly scans.
- **`go mod tidy -diff`** — fails instead of mutating; keeps `go.mod`/`go.sum` honest.
- **`-shuffle=on`** — flushes out inter-test ordering dependencies early.
- **`-race`** — mandatory, never dropped for speed. If the suite gets slow, fix the
  suite.
- **`@latest` on staticcheck/govulncheck is a deliberate exception** to version
  pinning: both are analysis gates, not build inputs — a new check can redden CI but
  can never change the shipped binary, and for these tools the newest checks *are* the
  point. If a staticcheck release breaks CI on an unrelated morning, pin that step to
  the previous version in the fixing PR and remove the pin once the findings are
  addressed.
- **Static build gate** — proves the CGO-free single-binary invariant every commit,
  not at release time.

## Dependency updates

Renovate or Dependabot, weekly schedule, gomod + github-actions ecosystems, all
updates grouped into one PR. Green CI (the workflow above) is the merge criterion —
that's what makes routine updates routine. Major-version bumps of the *pinned* stack
(Go, htmx) are never auto-merged: they go through [VERSIONS.md](../VERSIONS.md) first.

## Out of scope for CI

Deployment stays manual-and-trivial (`scp` + restart, see
[web-application.md](web-application.md)) until a project demonstrably needs more.
No release automation, no artifact registries, no CD pipelines by default.
