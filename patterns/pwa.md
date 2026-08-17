# Pattern: PWA Install

**Tier 3** (taste — choosing is the rule, so no waiver is needed) · Last verified: 2026-08-14

Whether the app is installable at all is a per-project choice; once it is, everything
below is tier 2. **The no-service-worker rule is not a choice either way** — an app that
skips the manifest still MUST NOT register one.

This document owns one decision: **how the app gets onto the home screen**, launching in
its own window under its own icon. The whole feature is one manifest, four PNG icons,
four lines in the layout head, and one `mime` line at boot. Zero JavaScript.

## Why there is no service worker

Install stopped requiring one when Chrome dropped the `fetch()`-handler clause in 108
(mobile) and 112 (desktop), and Safari never asked. Offline caching would make the client
a second source of truth — the bug factory [go-performance.md](go-performance.md) bans on
the server. Install does need HTTPS, which
[operations/web-application.md](../operations/web-application.md) mandates in production
and [local-https.md](local-https.md) supplies on a developer's machine, where install is
otherwise impossible to try.

A product that genuinely must work offline (field data entry, flaky networks) is a
different architecture — client-side state, sync, conflict resolution — not a manifest
and four icons on this one. Escalate to the user per the no-JS rule in
[stack/html.md](../stack/html.md); do not quietly register a worker.

## The manifest

`web/static/manifest.webmanifest` — embedded, immutable-cached, and version-busted like
every other asset:

```json
{
  "name": "AppName",
  "short_name": "AppName",
  "id": "/",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "background_color": "#fbfcfd",
  "theme_color": "#fbfcfd",
  "icons": [
    { "src": "/static/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/static/icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/static/icon-512-maskable.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```

`background_color` paints the launch splash and `theme_color` the window chrome. Neither
forks by scheme, so a dark-scheme user sees the light splash for a moment; accepted,
because the metas below correct the chrome and take precedence.

## Serving `.webmanifest`

Go's built-in mime table has no `.webmanifest` entry, and on Unix `mime.TypeByExtension`
merges whatever the host's own mime files say — so the served type depends on the machine.
Here the lookup returns `""`, `http.FileServerFS` sniffs, and the JSON goes out as
`text/plain`. One line in `cmd/server/main.go`, before the servers start, makes it the
same everywhere:

```go
// Go's built-in mime table lacks .webmanifest, and the system mime files it
// merges on Unix vary by host — without this line, so does the served type.
// The error is impossible for these valid literals.
_ = mime.AddExtensionType(".webmanifest", "application/manifest+json")
```

Everything else is already in place: the embedded static file server, the `immutable`
cache header, the `?v={{version}}` buster ([go-performance.md](go-performance.md)).

## Icons

Four PNGs in `web/static/`, exported once from the same source as `favicon.svg` and
committed. A one-time export with any tool is a design act, not a build step — the
no-pipeline rule of [go-performance.md](go-performance.md) holds.

| File | Size | Duty |
|---|---|---|
| `icon-192.png` | 192×192 | Required by the install criteria. Transparent and unpadded, like the favicon. |
| `icon-512.png` | 512×512 | Required too, and the source for splash screens and app lists. Transparent and unpadded. |
| `icon-512-maskable.png` | 512×512 | Android's shaped icons; its own file, `"purpose": "maskable"`, never `"any maskable"` on a shared one. Opaque — pad with the light `--color-bg` (`#fbfcfd`), keeping artwork inside the safe zone, a centered circle of radius 40% of the width. |
| `apple-touch-icon.png` | 180×180 | iOS home screen, linked from the head rather than the manifest — Safari prefers the head link. Opaque; iOS paints transparency black. |

## The head lines

The layout from [stack/html.md](../stack/html.md) gains exactly four lines, after the
favicon link. Nothing else in the shell changes:

```html
<link rel="manifest" href="/static/manifest.webmanifest?v={{version}}">
<link rel="apple-touch-icon" href="/static/apple-touch-icon.png?v={{version}}">
<meta name="theme-color" content="#fbfcfd" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0f1216" media="(prefers-color-scheme: dark)">
```

The `theme-color` pair is the scheme fork the manifest cannot express, and it overrides
the manifest's `theme_color`. Light comes first because `media` is not Baseline: a browser
that reads `theme-color` but not `media` takes the first tag, and one that reads neither
falls back to the manifest. Every fallback is another tint, never a broken page — which is
what makes an unsupported attribute acceptable here. CSP needs no change; the manifest is
same-origin ([security-headers.md](security-headers.md)).

## What install changes at runtime

Chromium offers install in its own UI once the criteria are met, and iOS users go Share →
Add to Home Screen. **iOS gives the installed app its own storage**, separate from Safari,
so the first launch starts a fresh session even when Safari holds one — not a bug, do not
chase it. The app in a browser tab stays complete: install is enhancement, the same bar
the stack holds htmx to.

## Rules

1. **No service worker — MUST NOT.** Not for offline, not for push, not "for later". A
   requirement that seems to need one is an architecture change: escalate to the user.
2. **`start_url`, `scope`, and `id` are the explicit values above.** Relative values
   resolve against the manifest's URL under `/static/` — and an omitted `scope` defaults
   to `start_url` minus its filename — so either would scope the app to `/static/`. An
   omitted `id` ties the app's identity to `start_url` and moves it whenever that moves.
3. **Manifest colors and the `theme-color` metas are conversions of `--color-bg`**, and
   change with it in the same commit — the lockstep discipline of
   [css-tokens.md](css-tokens.md) rule 7. Manifest colors are static sRGB, so `#fbfcfd`
   and `#0f1216` are the light and dark `--color-bg` converted. A themed project, or one
   on neumorphic whose ground moves ([css-surfaces.md](css-surfaces.md)), converts its own.
4. **Manifest icons version by filename.** The `immutable` cache is forever and a static
   manifest cannot call the `version` template function, so a changed `icon-*.png` is a
   renamed one (`icon-192-2.png`) shipped in the same commit as the manifest, and the new
   name becomes canonical — never rename it back. `apple-touch-icon.png` is exempt: its
   head link busts it with `?v={{version}}`.
5. **When a project opts in, all four icons ship** — each covers a platform surface the
   others don't.
6. **`display` is `standalone`.** Navigation survives losing browser chrome, because links
   and forms are the API.

## Anti-patterns

- ❌ A service worker with an empty `fetch` handler — Chrome ignores empty handlers, and
  the requirement it once satisfied is gone.
- ❌ Offline caching or an "app shell" — a second source of truth in the client.
- ❌ Web push — needs a service worker and scripting.
- ❌ Install-promo banners via `beforeinstallprompt` — JavaScript, and the browser already
  offers install in its own UI.
- ❌ Icon-generator packs (dozens of favicons plus `browserconfig.xml`) — the SVG favicon
  and these four PNGs cover every platform this stack targets.
- ❌ Rendering the manifest through a template to version its icon URLs — a route, a
  handler, a content-type, and `html/template` escaping applied to JSON, all to avoid
  renaming a file that changes once a year.
- ❌ `display: "fullscreen"` or `"minimal-ui"` — the first hides even the OS status bar,
  the second re-adds the chrome install was meant to shed.

## Facts verified (2026-08-13)

- Chrome 108/112 dropped the `fetch()` handler, and ignores empty ones:
  https://developer.chrome.com/blog/update-install-criteria
- Install criteria; service worker "not a requirement":
  https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable
- `scope` resolution and its default:
  https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/scope
- The meta overrides the manifest's `theme_color`:
  https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/theme_color
- Maskable safe zone, single-purpose icons: https://web.dev/articles/maskable-icon
- `theme-color` `media`, not Baseline:
  https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/meta/name/theme-color
- `.webmanifest` absent from Go's mime table; `mime.TypeByExtension` merges four
  `/etc` mime files on Unix (`mime/type_unix.go`) — Go 1.26.5, returns `""` on this machine
- Hex values: oklch → linear sRGB → gamma-encoded, the math shared with the
  [css-tokens.md](css-tokens.md) contrast checks
