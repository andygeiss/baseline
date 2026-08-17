# Pattern: Performance (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-17

The ops listener this document profiles through is tier 1 —
[go-http-server.md](go-http-server.md) owns it.

The stack is fast by construction — compiled Go, one process, SQLite in WAL mode,
HTML over the wire with no client framework tax. Performance work is therefore
*measurement-driven maintenance*, not architecture: *never optimize without a profile.*

## Measure

- **Profiles:** `net/http/pprof` on the localhost-only ops listener (see
  [operations/web-application.md](../operations/web-application.md)) —
  `go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30`.
- **Benchmarks:** stdlib `go test -bench . -benchmem` for hot paths (domain logic,
  rendering); compare changes with `benchstat` (dev-only tool, not a dependency).
  A benchmark accompanies any change justified by "performance".
- **Load sanity check** before first deploy: any HTTP load tool against the real
  binary; know your p99 at expected traffic so regressions are visible later.

## Build-time wins

- **PGO** (once production traffic exists): capture a 30 s CPU profile from production, commit it as
  `cmd/server/default.pgo` — next to the main package, which is where `go build`
  auto-detects it (the repo root is *not* checked). Typically 2–7 % CPU reduction;
  refresh the profile when the workload shifts materially.
- Release builds: `CGO_ENABLED=0 go build -trimpath ./cmd/server` (static binary,
  reproducible paths) — the same flags CI's build gate, `make build`, and the
  release workflow use, and no extra ones; one definition of "release-shaped".

## Runtime configuration

- **`GOMEMLIMIT`** MUST be set in production to ~85–90 % of the memory actually
  available to the process (e.g. `GOMEMLIMIT=450MiB` on a 512 MiB box/container).
  Prevents both OOM kills and over-eager GC.
- **`GOMAXPROCS`:** leave it alone — since Go 1.25 the runtime is cgroup-aware and
  respects container CPU limits on its own.

## HTTP layer

- **Static assets** (`/static/`): embedded files never change within a deployed
  binary, so serve with `Cache-Control: public, max-age=31536000, immutable` — a
  three-line wrapper around the file server, wired in `Routes()`:

  ```go
  func cacheImmutable(next http.Handler) http.Handler {
  	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
  		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
  		next.ServeHTTP(w, r)
  	})
  }
  ```

  Every `/static/` URL in templates carries a version-busting query string
  (`/static/css/app.css?v={{version}}` — the CSS *and* the htmx script). `version` is
  a template function registered via `Funcs` before parsing, returning the build
  version (see
  [operations/web-application.md](../operations/web-application.md)) — one template
  function, no asset pipeline. `immutable` without busting serves stale assets after
  a deploy, and a buster that repeats itself is the same bug wearing a query
  string — which is what *Naming the assets* below is about.
- **HTML responses:** `Cache-Control: no-store` for authenticated pages; dual-mode
  responses already send `Vary: HX-Request, HX-Boosted` via the render helper.
- **Compression happens at the reverse proxy**, which the deployment configures —
  and most proxies do **not** compress until told to. The app does not gzip. Keep
  the app boring; let the edge do edge work.
- **Keep fragments small.** The cheapest response is the one that only contains what
  changed — that's the htmx architecture doing the performance work for you.

### Naming the assets: the version string has to change when they do

`immutable` is a promise no reload can take back. A browser holding one of these
files never asks for it again — not on a reload, not on a hard reload, not for a
year. The version in the URL is the only thing that can break that promise, so
the rule is stricter than "read `debug.ReadBuildInfo`":

> **Two builds with different assets MUST NOT share a version string.**

[go-cli.md](go-cli.md)'s reader is the wrong one here. It answers `unknown` when
there is no VCS metadata, which is right for a tool printing `-version` and
wrong for this: `unknown` is the same string after every edit, so a developer is
served the stylesheet and the script from their first visit for as long as the
cache lives, with no reload able to shift it. The toolchain's own names fail the
same way from the other side — `(devel)` on an un-released build, and
`v0.3.0+dirty` on a tag built from an edited tree, which stays `v0.3.0+dirty`
through every further edit.

**A commit identifies a set of assets; an edited tree only identifies a boot.**
Three cases, in that order:

```go
// version is read once at boot: it is the boot log line, the /healthz field,
// and the cache-buster on every static asset.
var version = sync.OnceValue(func() string {
	info, ok := debug.ReadBuildInfo() // false outside module mode; reading the nil panics
	if !ok {
		return bootID()
	}
	return resolveVersion(info)
})

// resolveVersion picks the name for a build. It takes the build info rather
// than reading it, because the three cases it decides between cannot all be
// produced by the toolchain running the test.
func resolveVersion(info *debug.BuildInfo) string {
	// A real released version: go install of a tagged module. A tag built from
	// an edited tree is not one — "v0.3.0+dirty" is the same string after every
	// further edit, the exact thing this function exists to avoid — so it falls
	// through to the boot-by-boot name below.
	if v := info.Main.Version; v != "" && v != "(devel)" && !strings.HasSuffix(v, "+dirty") {
		return v
	}

	var revision string
	var edited bool
	for _, s := range info.Settings {
		switch s.Key {
		case "vcs.revision":
			revision = s.Value
		case "vcs.modified":
			edited = s.Value == "true"
		}
	}
	// A clean checkout names its assets by the commit they came from, so two
	// deployments of the same commit do not make anyone download them twice.
	if revision != "" && !edited {
		return revision[:min(len(revision), 12)]
	}
	return bootID()
}

// bootID names one run of an edited tree, which is the finest grain there is:
// the toolchain cannot tell two edits apart, but it can tell two starts apart.
func bootID() string {
	return strconv.FormatInt(time.Now().UnixMilli(), 36)
}
```

`resolveVersion` takes its `*debug.BuildInfo` as a parameter for one reason: the
test binary's own build is only ever one of the three cases, so the other two
are reachable only as table rows. Test all three — a released version used as it
is, a clean checkout named by its commit, and every edited-tree shape producing
a name that changes between boots. That last assertion is the one that catches a
regression, and it is written as `got != info.Main.Version`, not against a fixed
string.

Two consequences worth writing into the project's own developer documentation,
because both look like bugs the first time:

- **Restart after editing anything under `web/`, then reload.** The interface is
  embedded in the binary, so a template or stylesheet change does not exist
  until the binary is built again — and the immutable cache means reloading
  alone never shows it. The boot log names the version being served; that is the
  first thing to check when an edit to `web/` looks like it did nothing.
- **A redeploy of the same commit keeps the same asset names**, which is the
  point: nobody downloads the stylesheet twice because a machine was restarted.

## Database

- The two-pool WAL setup in [go-sqlite.md](go-sqlite.md) *is* the performance
  configuration; don't tune past it without a measured problem.
- Watch for N+1 query loops in handlers — fetch collections in one query with a JOIN.
- `EXPLAIN QUERY PLAN` any query touched by a slowness report; add the index it names.
  Every index is justified by a query, not by intuition.

## What not to do

- No caching layers (Redis, in-process LRU) until a profile proves rendering or
  queries are the bottleneck — a cache is a second source of truth and a bug factory.
- No goroutine-per-thing "optimizations" in request paths; the server already runs a
  goroutine per request.
- No micro-optimizing allocations outside a hot path a profile identified.
