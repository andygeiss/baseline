# Pattern: Go Project Layout

**Last verified: 2026-08-12**

Standard layout for a web application. Start smaller than this if the project is
smaller — directories are added when a file would otherwise get roommates it doesn't
like, never speculatively.

```
project/
├── assets.go                ← //go:embed of web/ → TemplatesFS + StaticFS (rule 5)
├── cmd/
│   └── server/
│       └── main.go          ← wiring only: config, deps, http.Server, shutdown
├── go.mod
├── internal/                ← all application code lives under internal/
│   ├── app/                 ← handlers, routing, middleware (the HTTP edge)
│   │   ├── <feature>.go     ← handlers grouped by feature, not by "handlers"
│   │   ├── forms.go         ← form structs + the Validator (go-forms-validation.md)
│   │   ├── middleware.go
│   │   ├── ops.go           ← /healthz + pprof for the ops listener (go-http-server.md)
│   │   ├── routes.go        ← the single place all routes are registered
│   │   └── views.go         ← the view struct every page embeds (go-forms-validation.md)
│   ├── domain/              ← core types + business rules; imports nothing above it
│   └── store/               ← persistence; implements interfaces the consumers define
├── Makefile                 ← command runner, copied from stack/makefile.md
├── README.md                ← links back to this baseline; records any deviations
└── web/
    ├── static/
    │   ├── css/app.css
    │   ├── favicon.svg
    │   └── js/htmx.min.js   ← vendored, the only JS
    └── templates/           ← html/template files (see htmx-server-rendering.md)
        ├── <feature>.html
        └── layout.html
```

## Rules

1. **`main.go` stays tiny** (< ~100 lines): read config, construct dependencies,
   call `app.New(...)`, run the server. All logic is in `internal/` where it's testable.
2. **`internal/` for everything.** Nothing is importable from outside; no `pkg/`
   directory. Extract a public module only when a second project actually imports it.
3. **Dependency direction:** `app → domain ← store`. `domain` imports neither.
   Interfaces are declared where they are *consumed* (e.g. `app` defines the
   `GameStore` interface it needs; `store` satisfies it).
4. **Group by feature, not by kind.** `internal/app/game.go` with its handlers,
   not `internal/handlers/` + `internal/services/` + `internal/models/` mirrors.
5. **Embed all assets** in the binary from the `web/` tree:

```go
//go:embed web/templates
var TemplatesFS embed.FS

//go:embed web/static
var StaticFS embed.FS
```

   Exported, in a root-level `assets.go` (the module root package): `//go:embed`
   cannot reach `../web` from `cmd/server`, so `main.go` imports the root package
   and passes both into `app.New`. Embedded paths keep their full prefix — strip it
   once at wiring time with `fs.Sub(StaticFS, "web")` (fail the boot on error) so
   `/static/css/app.css` resolves inside the sub-FS as `static/css/app.css` and
   `http.FileServerFS` works without a `StripPrefix`.
   The deliverable is a single static binary; `CGO_ENABLED=0 go build ./cmd/server`
   must suffice.
6. **Config via flags + environment,** stdlib `flag` only, with env vars as defaults:
   `HOST`, `PORT`, `DATABASE_URL`, `LOG_LEVEL` (full contract in
   [operations/web-application.md](../operations/web-application.md)). No config files
   until genuinely needed.
