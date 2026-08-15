# Operations: Web Application

**Last verified: 2026-08-15**

Deployment target: one small Linux VPS (or container), one binary, Caddy in front,
systemd keeping it alive, Litestream shipping backups. Boring, restorable, cheap.

## Topology

```
Internet ──► Caddy (:443, auto-HTTPS)  ──► app (127.0.0.1:8080)
                                            ├── ops listener (127.0.0.1:6060)  ← never public
                                            └── app.db (+ Litestream → S3)
```

- **TLS terminates at Caddy** — automatic Let's Encrypt, zstd/gzip compression,
  HTTP→HTTPS redirect, all in a four-line Caddyfile:

  ```
  example.com {
      encode zstd gzip
      reverse_proxy 127.0.0.1:8080
  }
  ```

- The app binds `127.0.0.1` only and trusts `X-Forwarded-For` **only** because nothing
  else can reach it. The header holds one address, not a chain: Caddy discards the
  `X-Forwarded-*` values a client sends and writes its own, so there is no
  attacker-controlled entry for the per-IP rate limiter
  ([patterns/go-auth-sessions.md](../patterns/go-auth-sessions.md)) to key on. Do not
  set `trusted_proxies` unless something really does sit in front of Caddy — that
  option is what makes it *keep* the incoming values.
  If exposed directly instead (`:443`), use `golang.org/x/crypto/acme/autocert` —
  but the proxy is the default; don't mix models.
- Progressive rule from the baseline still holds: the proxy adds TLS and compression,
  never correctness. `curl localhost:8080` on the box must fully work.

## Two listeners, one binary

- **`:8080` (localhost)** — the application (routes from
  [patterns/go-http-server.md](../patterns/go-http-server.md)).
- **`:6060` (localhost)** — ops mux, never proxied, MUST NOT be publicly reachable:
  - `GET /healthz` — 200 + JSON `{"status":"ok","version":…}`; pings the DB **via
    the read pool** with a 1 s timeout, 503 on failure. Never the write pool: its
    single connection is busy during any long write, and a
    ping queued behind it times out — a healthy app flapping 503. This is what
    systemd/uptime checks hit (via localhost).
  - `/debug/pprof/…` — `net/http/pprof` handlers. Being localhost-only *is* the
    access control.
  - The ops mux runs in its own `http.Server` with the same timeouts as the app
    server. A long profile survives the 30 s `WriteTimeout`: `profile?seconds=30`
    writes nothing until profiling ends, but `net/http/pprof` extends its own
    write deadline to `WriteTimeout + seconds` on every seconds-based handler.

## Version stamping

No ldflags ceremony — the toolchain already embeds VCS info, and
`-trimpath` keeps it. `debug.ReadBuildInfo` reports it as `info.Main.Version`:
the tag when HEAD sits on one, a pseudo-version otherwise, with `+dirty`
appended when the tree had uncommitted changes. The canonical reader is
`version()` in [patterns/go-cli.md](../patterns/go-cli.md) — it checks the
`ok` result, because a binary built outside module mode gets no `BuildInfo` at
all, and reading a field off the nil it returns panics at boot.

Read it once at boot. That one string is the boot log line, the `/healthz`
field, and the static-asset cache-buster
(see [patterns/go-performance.md](../patterns/go-performance.md)). Build
releases from clean checkouts, so no deployed version carries `+dirty`.

## systemd unit (the deployment mechanism)

```ini
[Unit]
Description=app
After=network.target

[Service]
ExecStart=/opt/app/server
DynamicUser=yes
; StateDirectory → /var/lib/app, owned, persistent: the SQLite file lives here.
; (systemd has no trailing comments — annotations get their own line.)
StateDirectory=app
Environment=ENV=prod PORT=8080 GOMEMLIMIT=450MiB LOG_LEVEL=info
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

Deploy = upload beside the live binary, then swap by rename (writing *over* a running
executable fails with `ETXTBSY`; renaming does not):

```
scp server app:/opt/app/server.new
ssh app 'cd /opt/app && cp server server.prev && mv server.new server && systemctl restart app'
```

Graceful shutdown (already mandatory) makes the restart invisible; `server.prev` is
the instant rollback. Anything fancier (blue-green, containers, Kubernetes) needs a
written justification — this stack's whole point is not needing it.

Two adjustments when the defaults meet reality:

- **Secrets** (SMTP keys, S3 credentials for Litestream) MUST NOT go in
  `Environment=` lines — unit files are world-readable. Use systemd credentials
  (`LoadCredential=smtp-key:/etc/app/smtp-key`); the app reads the file named by
  `$CREDENTIALS_DIRECTORY`. Nothing else — no vault until a project genuinely needs one.
- **When Litestream is used,** replace `DynamicUser=yes` with a static system user
  (`User=app`) shared by both units — the replica sidecar must read the database
  directory, and a transient UID makes that fragile.

## Backups & logs

- **Litestream** runs as its own systemd service replicating `/var/lib/app/app.db` to
  S3-compatible storage (see [patterns/go-sqlite.md](../patterns/go-sqlite.md)).
  Rehearse `litestream restore` before launch.
- App logs to stdout → journald owns retention (`journalctl -u app`). No log files,
  no rotation config.

## Environment contract

The binary is configured by exactly these. `HOST`, `PORT`, `DATABASE_URL`, and
`LOG_LEVEL` are flags with env-var defaults (a flag overrides its env var);
`ENV` and `GOMEMLIMIT` are read from the environment only. Secrets are not in
this table on purpose — they arrive as systemd credentials, per the section
above. The parser that produces both is
[patterns/go-config.md](../patterns/go-config.md):

| Var | Meaning | Default |
|---|---|---|
| `HOST` | bind address | `127.0.0.1` (the proxy is the public listener) |
| `PORT` | app listener port | `8080` |
| `DATABASE_URL` | SQLite file path | `app.db` |
| `LOG_LEVEL` | slog level | `info` |
| `ENV` | `dev` / `prod` (text vs JSON logs) | `dev` |
| `GOMEMLIMIT` | runtime memory limit | set in unit file |
