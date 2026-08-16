# Pattern: Local HTTPS

**Last verified: 2026-08-16**

The one decision this document owns: **how a developer reaches the app from a
phone over HTTPS**. Browsers lock a family of features behind a secure context,
and `localhost` is the only insecure origin they treat as one. So a phone on the
same network gets none of them, and every feature in that family is untestable
on the machine that serves it.

This is opt-in. A project whose features all work over plain HTTP skips this
document and loses nothing. A project that needs one of the features below
cannot skip it, because there is no other way to see the feature run.

## What needs a secure context

A browser grants these only on HTTPS, `http://localhost`, or `http://127.0.0.1`:

| Feature | Where it appears here |
|---|---|
| `getUserMedia` — microphone, camera | any voice or video feature |
| Service workers, and PWA install | [pwa.md](pwa.md) |
| Geolocation | any "near me" feature |
| Notifications, Push | — |
| WebAuthn — passkeys, security keys | [go-auth-sessions.md](go-auth-sessions.md) |
| `navigator.clipboard.readText` | copy-and-paste helpers |

**A LAN address is not a secure context.** `http://192.168.1.20:8080` is an
ordinary insecure origin, so the phone silently loses every row above. The app
does not break — a well-built feature says why it is unavailable — but nobody
can try it.

This bites the install pattern hardest. [pwa.md](pwa.md) requires the manifest
"served over HTTPS", and
[operations/web-application.md](../operations/web-application.md) mandates that
**on the server**. Nothing mandates it on a developer's machine, so install is
the one feature in this corpus that cannot be checked before it ships without
this document.

## The binary still never speaks TLS

That rule does not bend
([project-types/web-application.md](../project-types/web-application.md)). The
binary stays on `127.0.0.1`, and a proxy in front terminates TLS — Caddy on the
server, Caddy on the developer's machine. Same shape, two places:

```
phone ──TLS──▶ Caddy ──plain HTTP──▶ binary on 127.0.0.1:8080
```

Nothing about the application changes to make this work. `curl` against the
binary still works with nothing in front, and the app is not made to know
whether a proxy is there.

## The Caddyfile

One file, `Caddyfile.lan` at the repository root:

```caddyfile
{
	admin off
	auto_https disable_redirects
}

{$LAN_HOST:localhost}:8443 {
	tls internal
	encode zstd gzip
	reverse_proxy 127.0.0.1:8080
}
```

Four decisions in nine lines:

- **`tls internal`** signs with Caddy's own certificate authority. No public
  issuer signs a `.local` name, so no public issuer is asked.
- **`auto_https disable_redirects`** stops Caddy binding `:80` to redirect to
  `:443` — a port this file does not serve, so the redirect would land on a
  closed door.
- **`admin off`** because nothing here drives Caddy over its API.
- **Port 8443, not 443.** A port below 1024 needs root, and testing a change on
  a phone should not.

## The Makefile target

`stack/makefile.md` rule 3 already allows this: a target for a real recurring
command. It is one line, and it belongs to the project rather than to the
canonical Makefile — a CLI or a library has no use for it.

```make
lan:
	LAN_HOST="$$(scutil --get LocalHostName).local" caddy run --config Caddyfile.lan
```

The name comes from the machine's own mDNS name, which every device on the
network already resolves. That is the whole reason to use it: no DNS to run,
and no address to retype when the router hands out a different one. `scutil` is
macOS; on Linux the same name comes from Avahi.

Run it beside `make run`, in a second shell. It is not a replacement — the
binary still has to be up, and Caddy answers 502 until it is.

**Use the Caddy line the operations repository pins.** Do not add a second pin
here: two places to update is how a version drifts, and that repository is the
one that knows which Caddy is in production.

## Trust the certificate on the device

The certificate authority is local, so every device has to be told about it
once. On iOS, in this order:

1. AirDrop the root certificate. It is at
   `~/Library/Application Support/Caddy/pki/authorities/local/root.crt` on
   macOS, and `$XDG_DATA_HOME/caddy/pki/authorities/local/root.crt` elsewhere.
2. **Settings → Profile Downloaded → Install**.
3. **Settings → General → About → Certificate Trust Settings**, and switch the
   root on.

**Step 3 is not optional and is the one people miss.** Without it the device
installs the certificate and still refuses the site, with an error that never
mentions trust.

For the developer's own browser, `sudo caddy trust` once. Caddy attempts this
the first time it starts and logs `failed to install root certificate` when it
cannot ask for a password.

Android's path differs and is not verified here.

## What this changes on the device, for a year

The app sends `Strict-Transport-Security`
([security-headers.md](security-headers.md)). Once the device has loaded that
host over HTTPS it refuses plain HTTP on the same host until the header
expires. That is the point of the header, and it is still worth knowing before
it surprises someone: the plain-HTTP address on that hostname stops working,
including on a different port.

## Rules

1. **The binary MUST NOT serve TLS**, in development or anywhere else. A
   `-tls-cert` flag is the anti-pattern this whole document exists to avoid.
2. **`Caddyfile.lan` MUST NOT be a copy of the deployment Caddyfile** under
   local edits. It is a different artefact for a different machine: a `.local`
   name, a local authority, a loopback upstream. The operations repository owns
   the one the server runs, and forbids application repositories from keeping
   edited copies of its templates.
3. **Nothing here reaches the server.** No image builds it in, and no runbook
   reads it. A deployment that needs this file is a deployment doing something
   wrong.
4. **The certificate authority stays on the machine that made it.** Never commit
   a root certificate or its key, and never reuse this authority for anything a
   user touches.
5. **A project that opts in says so in its README**, next to how to run it —
   the feature it unlocks is invisible until someone follows the steps.

## Anti-patterns

- ❌ Making the binary terminate TLS for development. It splits the server into
  two shapes, and the one nobody deploys is the one that gets tested.
- ❌ Copying `baseline-ops/templates/Caddyfile` and editing it down. Copies
  nothing builds drift; this is a separate file with a separate job.
- ❌ `--unsafely-treat-insecure-origin-as-secure`, or any flag that switches off
  the browser's own rule. It is desktop-only, so it cannot test the device the
  feature is for, and it hides exactly the failure a user would hit.
- ❌ A bare self-signed certificate with no authority behind it. Trust then
  attaches to that one certificate, so every regeneration is another trip
  through the device's settings — and the server certificate here is replaced
  twice a day. Trusting a root is done once and covers every certificate it
  goes on to sign.
- ❌ Pinning a Caddy version in this document or in a project's Makefile. The
  operations repository pins it.
- ❌ Checking a device feature on a desktop browser and assuming the phone
  agrees. Safari on iOS is the strictest implementation of every row in the
  table above, and it is usually the target.

## Facts verified (2026-08-16)

Checked by running it, not by reading about it:

- Caddy **2.11.4** with the Caddyfile above serves
  `https://<name>.local:8443` with `curl --cacert <root> …` reporting
  `ssl_verify_result=0`, and proxies through to a Go binary on
  `127.0.0.1:8080`. The same request forced through the machine's LAN address
  also answers 200, which is the path a phone takes.
- Without `auto_https disable_redirects`, Caddy binds a second listener on
  `:80` and redirects to `:443`, which this configuration does not serve. With
  it, `lsof` shows one listener on `:8443`.
- The root certificate Caddy generated is valid for **ten years**; the
  certificate it serves is valid for **twelve hours** and is renewed while
  Caddy runs. Only the root is installed on a device.
- `sudo caddy trust` is what installs the root into the host's own store.
  Started without a terminal to prompt on, Caddy logs
  `failed to install root certificate` and serves correctly anyway.

Sources:

- Secure contexts, and why `localhost` is exempt:
  https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts
- Features restricted to secure contexts:
  https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts/features_restricted_to_secure_contexts
- Caddy `tls internal` and the local authority:
  https://caddyserver.com/docs/caddyfile/directives/tls and
  https://caddyserver.com/docs/automatic-https#local-https
- `auto_https` options:
  https://caddyserver.com/docs/caddyfile/options#auto-https
