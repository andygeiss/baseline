# Operations: Web Application

**Last verified: 2026-08-10**

Deployment target: one small Linux VPS (or container), one binary, Caddy in front,
systemd keeping it alive, Litestream shipping backups. Boring, restorable, cheap.

## Topology

```
Internet ──► Caddy (:443, auto-HTTPS)  ──► app (127.0.0.1:8080)
                                            ├── ops listener (127.0.0.1:6060)  ← never public
                                            └── app.db (+ Litestream → S3)
```

- **TLS terminates at Caddy** — automatic Let's Encrypt, zstd/gzip compression,
  HTTP→HTTPS redirect, all in a 5-line Caddyfile:

  ```
  example.com {
      encode zstd gzip
      reverse_proxy 127.0.0.1:8080
  }
  ```

- The app binds `127.0.0.1` only and trusts `X-Forwarded-For` **only** because nothing
  else can reach it. If exposed directly instead (`:443`), use `golang.org/x/crypto/acme/autocert` —
  but the proxy is the default; don't mix models.
- Progressive rule from the baseline still holds: the proxy adds TLS and compression,
  never correctness. `curl localhost:8080` on the box must fully work.

## Two listeners, one binary

- **`:8080` (localhost)** — the application (routes from
  [patterns/go-http-server.md](../patterns/go-http-server.md)).
- **`:6060` (localhost)** — ops mux, never proxied, MUST NOT be publicly reachable:
  - `GET /healthz` — 200 + JSON `{"status":"ok","version":…}`; pings the DB with a
    1 s timeout, 503 on failure. This is what systemd/uptime checks hit (via localhost).
  - `/debug/pprof/…` — `net/http/pprof` handlers. Being localhost-only *is* the
    access control.

## Version stamping

No ldflags ceremony — the toolchain already embeds VCS info. Read it at startup:

```go
info, _ := debug.ReadBuildInfo() // vcs.revision, vcs.time, vcs.modified
```

Log it at boot, expose it in `/healthz`, use it as the static-asset cache-buster
(see [patterns/go-performance.md](../patterns/go-performance.md)). Build releases from
clean checkouts so `vcs.modified` is false.

## systemd unit (the deployment mechanism)

```ini
[Unit]
Description=app
After=network.target

[Service]
ExecStart=/opt/app/server
DynamicUser=yes
StateDirectory=app            # → /var/lib/app, owned, persistent: the SQLite file lives here
Environment=PORT=8080 GOMEMLIMIT=450MiB LOG_LEVEL=info
Environment=DATABASE_URL=/var/lib/app/app.db
Restart=on-failure
RestartSec=2

# Hardening — keep all of these
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
NoNewPrivileges=yes
CapabilityBoundingSet=

[Install]
WantedBy=multi-user.target
```

Deploy = `scp` new binary + `systemctl restart app`. Graceful shutdown (already
mandatory) makes the restart invisible; keep the previous binary as `server.prev` for
instant rollback. Anything fancier (blue-green, containers, Kubernetes) needs a
written justification — this stack's whole point is not needing it.

## Backups & logs

- **Litestream** runs as its own systemd service replicating `/var/lib/app/app.db` to
  S3-compatible storage (see [patterns/go-sqlite.md](../patterns/go-sqlite.md)).
  Rehearse `litestream restore` before launch.
- App logs to stdout → journald owns retention (`journalctl -u app`). No log files,
  no rotation config.

## Environment contract

The binary is configured by exactly these (flags override, envs default):

| Var | Meaning | Default |
|---|---|---|
| `PORT` | app listener port | `8080` |
| `DATABASE_URL` | SQLite file path | `app.db` |
| `LOG_LEVEL` | slog level | `info` |
| `ENV` | `dev` / `prod` (text vs JSON logs) | `dev` |
| `GOMEMLIMIT` | runtime memory limit | set in unit file |
