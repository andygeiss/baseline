# Operations: CI

**Last verified: 2026-08-15**

The [checklists](../checklists/)' mechanical items run on every push to `main`
and every PR —
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
      - uses: actions/checkout@v7

      - uses: actions/setup-go@v7
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
  module's Go version; patch releases are security releases. Since `setup-go@v6` the
  action also exports `GOTOOLCHAIN=local`, so `go` runs the toolchain the action just
  installed instead of silently downloading another one. That is the behaviour this
  baseline wants: if `go.mod` ever declares a Go version newer than the installed one,
  CI fails loudly instead of testing a Go release nobody pinned.
- **Action majors are pinned in [VERSIONS.md](../VERSIONS.md)** — `checkout@v7` and
  `setup-go@v7` are the current majors and run on **Node 24**. `checkout@v4` and
  `setup-go@v5` — the versions most training data still suggests — target the
  deprecated Node 20 runtime: GitHub force-runs those on Node 24 anyway and annotates
  every run. Bump on the deprecation warning, not after the removal.
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
- **Static build gate** — proves the CGO-free single-binary invariant on every CI
  run, not at release time.

## Local mirror

`make check` ([stack/makefile.md](../stack/makefile.md)) runs these gates
gate-for-gate — same commands, same flags, same order — so "green locally" means
"green in CI". Any change to this workflow MUST land in the canonical Makefile in
the same commit, and vice versa. CI keeps its explicit named steps instead of
calling `make check`: per-gate red/green in the Actions UI is worth the
duplication.

## Dependency updates

Renovate or Dependabot, weekly schedule, gomod + github-actions ecosystems, all
updates grouped into one PR. Green CI (the workflow above) is the merge criterion —
that's what makes routine updates routine. Major-version bumps of the *pinned* stack
(Go, htmx) are never auto-merged: they go through [VERSIONS.md](../VERSIONS.md) first.

## Out of scope for CI

**CI never deploys, and this repository does not describe deployment at all.**
How a web application reaches a server — and which server — belongs to the
operations repository (`baseline-ops`), because it changes only the server. What
belongs here is the contract the binary must satisfy:
[web-application.md](web-application.md).

The division of labour is the point: CI answers "is this code good?", and a
person answers "should this go live now?". No CD pipeline, no deploy key in a
repository secret. A CLI tool is the one exception, and only because its release
*is* its distribution — [cli-release.md](cli-release.md) owns that tagged
workflow.

CI also builds no container image, whatever the deployment turns out to run.
The lockstep rule above would pull that step into `make check` as well, and then
every local `make` would need a container runtime up — to build a file this
repository does not own.
