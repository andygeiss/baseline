# Pattern: Performance (Go)

**Last verified: 2026-08-10**

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

## Build-time wins (free, always on)

- **PGO:** capture a 30 s CPU profile from production, commit it as `default.pgo` in
  the repo root — `go build` picks it up automatically (typically 2–7 % CPU
  reduction). Refresh the profile when the workload shifts materially.
- Release builds: `go build -trimpath -ldflags="-s -w" ./cmd/server`
  (reproducible paths, smaller binary; symbols stay available via DWARF-less pprof).

## Runtime configuration

- **`GOMEMLIMIT`** MUST be set in production to ~85–90 % of the memory actually
  available to the process (e.g. `GOMEMLIMIT=450MiB` on a 512 MiB box/container).
  Prevents both OOM kills and over-eager GC.
- **`GOMAXPROCS`:** leave it alone — since Go 1.25 the runtime is cgroup-aware and
  respects container CPU limits on its own.

## HTTP layer

- **Static assets** (`/static/`): embedded files never change within a deployed
  binary, so serve with `Cache-Control: public, max-age=31536000, immutable` and a
  version-busting query string (`/static/css/app.css?v={{.Version}}`, version from
  build info — one template variable, no asset pipeline).
- **HTML responses:** `Cache-Control: no-store` for authenticated pages; dual-mode
  responses already send `Vary: HX-Request`.
- **Compression happens at the reverse proxy** (Caddy: zstd/gzip, on by default) —
  the app does not gzip. Keep the app boring; let the edge do edge work.
- **Keep fragments small.** The cheapest response is the one that only contains what
  changed — that's the htmx architecture doing the performance work for you.

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
