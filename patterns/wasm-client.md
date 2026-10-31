# Pattern: WebAssembly Client

**Tier 2** (shape — waived only on the record) · Last verified: 2026-10-31

**Three rules here are tier 1 and never waived:** the socket's handshake refuses any
`Origin` that is not the page's own host, the socket acts only under what the cookie
already holds (rule 6), and the policy gains `'wasm-unsafe-eval'` and nothing else
([security-headers.md](security-headers.md) owns it).

A web application whose page is a program — a game, a simulation, a canvas redrawn every
frame — written in Go, compiled to WebAssembly, and talking to the server over one
WebSocket. HTML and htmx cannot draw sixty frames a second, so this is the one shape
where the no-JavaScript rule ([stack/html.md](../stack/html.md)) bends. **Choosing it
is a shape decision the brief settles.** A feature htmx can render is not one: every page
around the program — the lobby, the forms, the settings — is still hypermedia and works
with scripts off.

## The module

1. **TinyGo builds it.** Size is the claim a module makes, and standard Go's `js/wasm`
   starts at about 1.9 MB for a `println`. Its version is
   [VERSIONS.md](../VERSIONS.md)'s TinyGo row, named exactly in a Makefile variable that
   `make wasm` checks against `tinygo version` ([stack/makefile.md](../stack/makefile.md)
   rules 4 and 5). That row also bounds the Go row: a Go minor TinyGo cannot build waits.
   A project moves with the row and rebuilds its module in the same commit. A second
   optimizer after TinyGo, such as `wasm-opt`, is a tool like any other: its version is
   named and checked the same way.
2. **The module is committed and embedded.** `make ci` needs no TinyGo; `make wasm`, a
   rule-3 target, rebuilds it. Beside each module it writes a `.build` file (compiler
   version and flags) and a `.sum` of its inputs — every Go file the `js/wasm` target
   compiles, `go.mod`, and the `.build`. **A server test recomputes the digest**, so a
   source change cannot ship with an old module. Both files sit under `web/static/` and
   are served with it; they hold nothing secret.
3. **Two gate lines in `check`** (rule 1): `GOOS=js GOARCH=wasm go vet` over every
   package the module is made of, because the host vet never sees a `js && wasm` file,
   and a size limit per module, its number in a variable `make wasm` tests too.
   `staticcheck` and `go fix -diff` are as blind to those files; a project may give each
   a `js/wasm` line of its own, and nothing else checks them. The lines are
   `GOOS=js GOARCH=wasm go fix -diff ./...` and `go run -exec 'env GOOS=js GOARCH=wasm'
   honnef.co/go/tools/cmd/staticcheck@latest ./...`: with `GOOS` in front, `go run`
   builds staticcheck itself for the browser, and it cannot start.
4. **The browser packages stay small.** A `deps_test.go`
   ([go-project-layout.md](go-project-layout.md) rule 3) keeps `net/http`, `os/signal`,
   and `golang.org/x/sync` out of every package the module compiles. Code both sides
   share — the rules, the wire format — lives in packages that pass it.

## The two scripts

Under `web/static/js/`, beside htmx, and nothing else:

- **`wasm_exec.js`**, copied by `make wasm` from the TinyGo that built the module, and
  never edited. It must match its compiler.
- **One loader**, `wasm_app.js`: it reads the module's path from a `data-module`
  attribute and starts it. It may publish what Go cannot reach on its own (the module's
  memory, the GPU's name), and it decides nothing: every branch on game or page state is
  the module's. No build step, no npm, no framework.

Both load deferred in `<head>`, on the module's page only: a script in `<body>` runs
again on every boosted swap. A boosted link swaps only the body, so the link *into* that
page carries `hx-boost="false"`, and a boosted link *out* leaves the module running —
it stops itself, socket and all, once its canvas has left the document.

A script for anything else — a browser API with no Go reach, like audio after a gesture —
is a waiver in the project's README, not this pattern.

## The socket

The module's input goes up over one WebSocket, opened with `GET /ws`. It is the one GET
that mutates, and the reason is the browser's: a WebSocket opens with a GET.

5. **The handshake checks `Origin` itself — tier 1.** `http.CrossOriginProtection`
   always lets a GET through, so it never sees this request. Refuse with 403 an `Origin`
   whose host is not `r.Host`, or no `Origin` at all. The session cookie is
   `SameSite=Lax`, so without the check the socket still opens for any other origin the
   cookie reaches — a sibling subdomain — or any page in a browser that ignores
   `SameSite`. An authentication guard that runs first may refuse with 401 instead; what
   matters is that no refused request is upgraded.
6. **Everything that creates state is a POST form first** — tier 1 where it says what
   the socket may act under. An identity, a room, a session, any record that outlives
   the socket, is made by a plain form; the socket acts only under what the cookie
   already holds. What dies with the connection — a position, who is looking — the
   socket may keep.
7. **The socket is capped like a body.** A message size (1 KiB is plenty for input), the
   messages a second, and the queue toward a slow client. Past a cap the server closes
   the socket, it does not buffer, and the code says which cap: 1009 too big, 1008 too
   many or malformed, 1013 a reader too slow, which a client may retry.
8. **Hijack, then own the deadlines.** `http.ResponseController` calls a wrapper's own
   `Hijack` method if it has one, else follows its `Unwrap` (scs's has only that); a
   wrapper with neither fails with `ErrNotSupported`. `Hijack` leaves the connection
   with no deadline (Go clears the server's; the `Hijacker` doc allows that it may not),
   so set the socket's own read and write deadlines before the first read. `srv.Shutdown`
   does not track a hijacked connection, so shutdown closes every socket with 1001 and
   then waits for its goroutines ([go-background-work.md](go-background-work.md)) —
   before the session store and the database close, since session middleware still runs
   when the handler returns.

The standard library has no WebSocket. Writing the server half by hand — RFC 6455's
framing, binary messages only — is what the first projects did. A dependency is the other
road, justified in the README like any outside [stack/go.md](../stack/go.md)'s list.
The socket carries the module's bytes, never HTML, so it is not the htmx WebSocket
extension [htmx-live-updates.md](htmx-live-updates.md) refuses.

## Anti-patterns

- ❌ `'unsafe-eval'` to make the module load. It allows JavaScript `eval` too;
  `'wasm-unsafe-eval'` allows WebAssembly and nothing else.
- ❌ An edited `wasm_exec.js`. The next `make wasm` overwrites it, and a copy that no
  longer matches its compiler fails at run time, not at build time.
- ❌ A module built by CI or at boot. The committed bytes are the release.

## Facts verified (2026-10-31)

- `ResponseController.Hijack` calls the writer's `Hijack` if it is a `Hijacker`, else
  follows `Unwrap`, and returns an error matching `ErrNotSupported` for a writer with
  neither: `net/http/responsecontroller.go`, Go 1.27.3
- The server's `Hijack` clears the connection's deadlines (`rwc.SetDeadline(time.Time{})`
  in `(*conn).hijackLocked`, `net/http/server.go` line 326); the `Hijacker` doc says they
  may remain: Go 1.27.3
- Without `'wasm-unsafe-eval'` (or `'unsafe-eval'`) in `script-src`, a page under a CSP
  cannot compile WebAssembly; `'unsafe-eval'` also allows `eval`:
  https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/script-src
- `CrossOriginProtection` always allows GET, HEAD and OPTIONS: `go doc
  net/http.CrossOriginProtection`, Go 1.27.3
- The browser sends `Origin` on the handshake and the server is to check it:
  https://www.rfc-editor.org/rfc/rfc6455#section-10.2
- `GOOS=js GOARCH=wasm go build -trimpath` of a `println` main in `module x`: 1,889,724
  bytes, about 1.9 MB; without `-trimpath` the size moves with the build directory, Go
  1.27.3
- `GOOS=js GOARCH=wasm go run …staticcheck@latest` fails with `exec format error`; the
  `-exec 'env GOOS=js GOARCH=wasm'` form reports findings in a `js && wasm` file, Go 1.27.3
