# Pattern: PWA Install

**Last verified: 2026-08-13**

The one decision this document owns: **how the app gets onto the home
screen** — installed from the browser, launching in its own window under its
own icon. The whole feature is one manifest, four PNG icons, four lines in
the layout head, and one `mime` line at boot. Zero JavaScript, zero new
machinery. Install is opt-in per project — an app nobody installs skips this
document and loses nothing else.

## Why there is no service worker

A service worker is hand-written JavaScript, and this pattern needs none:

- **Install stopped requiring one.** Chromium's criteria are the manifest
  below — `name` (or `short_name`), 192 px and 512 px icons, `start_url`,
  `display`, and `prefer_related_applications` false or absent (the manifest
  omits it) — served over HTTPS, which
  [operations/web-application.md](../operations/web-application.md) already
  mandates. A service worker is not on that list. Chrome retired the last
  clause that implied one, "has a `fetch()` handler", from menu install in
  108 (mobile) and 112 (desktop). Safari never asked for one.
- **Offline contradicts the architecture.** The server is the source of truth;
  a service worker replaying cached HTML is a second source of truth — the
  same bug factory the "no caching layers" rule in
  [go-performance.md](go-performance.md) bans on the server. When the network
  is gone this app *is* gone, and the browser's own offline page says so
  truthfully.
- **The old workaround no longer pays.** A service worker with an empty
  `fetch` handler, written only to pass the pre-108 check, passes nothing
  today. Chrome now ignores empty handlers outright — the fix it shipped once
  the workaround started hurting page loads. What is left is a second program,
  with its own install, update, and scope rules, running for no reason.

A product that genuinely must work offline (field data entry, flaky networks)
is a different architecture — client-side state, sync, conflict resolution —
not a manifest and four icons on this one. Escalate to the user, per the
no-JS rule in [stack/html.md](../stack/html.md); do not quietly register a
worker.

## The manifest

`web/static/manifest.webmanifest` — embedded, immutable-cached, and
version-busted like every other asset:

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

- **`start_url` and `scope` MUST be the explicit `"/"`.** Relative values
  resolve against the manifest's own URL — under `/static/` — and an omitted
  `scope` defaults to `start_url` minus its filename, so a relative
  `start_url` would scope the app to `/static/`. Unlike a service worker,
  `scope` has no directory restriction: `"/"` is legal from anywhere.
- **`id` names the installed app** independent of the URLs around it; without
  it, identity falls back to `start_url`. Stating it costs one line, and the
  identity survives any later `start_url` change.
- **The colors are `--color-bg`, converted.** Manifest colors are static sRGB,
  so `#fbfcfd` is the light-scheme `oklch(99% 0.002 260)` from
  [css-tokens.md](css-tokens.md), run through a throwaway script that reuses
  the contrast checks' oklch → linear-sRGB math and gamma-encodes to hex.
  Every hex in this document is that minimal, unthemed starting set; a themed
  project — or one on the neumorphic style, whose ground moves
  ([css-surfaces.md](css-surfaces.md)) — converts its own value. When
  `--color-bg` changes, reconvert both members here and the two `theme-color`
  metas below in the same commit: the lockstep discipline of
  [css-tokens.md](css-tokens.md) rule 7.
- **`background_color` paints the launch splash, `theme_color` the window
  chrome.** Neither forks by scheme, so a dark-scheme user sees the light
  splash for a moment. Accepted: the manifest has no scheme fork, and the
  chrome tint is corrected by the two `theme-color` metas below, which take
  precedence over this member.
- **`display: standalone`** — the app in its own window, browser chrome
  hidden. Navigation already survives that: links and forms are the API, and
  the layout shell wraps every page.

## Serving `.webmanifest`

Go's *built-in* mime table has no `.webmanifest` entry, and on Unix
`mime.TypeByExtension` also merges whatever the host's own mime files say
(`/etc/mime.types` and three siblings). The served type therefore depends on
the machine: on this one the lookup returns `""`, so `http.FileServerFS`
sniffs and the JSON goes out as `text/plain`, while a box whose mime files do
carry the entry would send the right type by luck. One line in
`cmd/server/main.go`, before the servers start, makes it the same everywhere:

```go
// Go's built-in mime table lacks .webmanifest, and the system mime files it
// merges on Unix vary by host — without this line, so does the served type.
// The error is impossible for these valid literals.
_ = mime.AddExtensionType(".webmanifest", "application/manifest+json")
```

Everything else is already in place: the embedded static file server, the
`immutable` cache header, the `?v={{version}}` buster
([go-performance.md](go-performance.md)). One consequence needs a rule: **the
icon URLs inside the manifest cannot carry the buster** — a static file cannot
call the `version` template function. A changed manifest icon therefore gets a
new filename, and the manifest changes in the same commit. The two
head-linked files, the manifest itself and `apple-touch-icon.png`, carry
`?v={{version}}` like every other asset in the shell and need no rename.
Deploys that leave icons alone need nothing.

## Icons

Four PNGs in `web/static/`, exported once from the same source as
`favicon.svg` and committed. A one-time export with any tool is a design act,
not a build step — the no-pipeline rule of
[go-performance.md](go-performance.md) holds.

| File | Size | Duty |
|---|---|---|
| `icon-192.png` | 192×192 | Required by the install criteria. |
| `icon-512.png` | 512×512 | Required too, and the source for splash screens and app lists. |
| `icon-512-maskable.png` | 512×512 | Android's shaped icons. Opaque — pad with the light `--color-bg` (`#fbfcfd`, the manifest's `background_color`); artwork stays inside the safe zone, a centered circle with radius 40% of the width; platforms may crop everything outside it. |
| `apple-touch-icon.png` | 180×180 | iOS home screen. Opaque — flatten onto the same `#fbfcfd`; iOS paints transparency black. |

- **Maskable is its own file**, declared `"purpose": "maskable"` — never
  `"any maskable"` on one icon. The two plain icons stay transparent and
  unpadded, like the favicon; the padding a mask needs would make the same
  artwork read small everywhere masks don't apply.
- **`apple-touch-icon.png` is linked from the head, not the manifest** —
  Safari takes the head link over manifest icons.

## The head lines

The layout from [stack/html.md](../stack/html.md) gains exactly four lines,
after the favicon link. Nothing else in the shell changes:

```html
<link rel="manifest" href="/static/manifest.webmanifest?v={{version}}">
<link rel="apple-touch-icon" href="/static/apple-touch-icon.png?v={{version}}">
<meta name="theme-color" content="#fbfcfd" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0f1216" media="(prefers-color-scheme: dark)">
```

- **The `theme-color` pair is the scheme fork the manifest cannot express.**
  It tints the browser and OS chrome around the page and takes precedence over
  the manifest's `theme_color`. The pair mirrors `--color-bg`: `#0f1216` is
  the dark-scheme `oklch(18% 0.01 260)`. The `media` attribute is not
  Baseline, which is why light comes first — a browser that reads
  `theme-color` but not `media` takes the first tag, and one that reads
  neither falls back to the manifest. Every fallback is another tint, never a
  broken page — which is what makes an unsupported tag acceptable here.
- CSP needs no change: the manifest is same-origin, and `manifest-src` falls
  back to the `default-src 'self'` already set in
  [go-http-server.md](go-http-server.md).

## What install changes at runtime

- Chromium browsers offer install in their own UI (omnibox, menu) once the
  criteria are met — no prompt code; `beforeinstallprompt` is JavaScript and
  stays unwritten. On iOS the user installs via Share → Add to Home Screen;
  Safari shows no prompt at all.
- **iOS gives the installed app its own storage**, separate from Safari: the
  first launch starts a fresh session even when Safari holds one. Sessions
  behave normally from then on. Not a bug; do not chase it.
- The app in a browser tab stays complete — install is enhancement, the same
  bar the stack holds htmx to.

## Rules

1. **No service worker — MUST NOT.** Not for offline, not for push, not "for
   later". A requirement that seems to need one is an architecture change:
   escalate to the user.
2. **`start_url`, `scope`, and `id` are explicit** in every manifest — a
   relative `start_url` or `scope` resolves against `/static/` and scopes the
   app wrong; an omitted `id` ties identity to `start_url`.
3. **Manifest colors and `theme-color` metas are conversions of
   `--color-bg`** and change with it in the same commit.
4. **Manifest icons version by filename.** The `immutable` cache is forever
   and a static manifest cannot call `version`, so a changed `icon-*.png` is a
   renamed one (`icon-192-2.png`); the new name becomes the canonical one —
   never rename it back to the table's starting names. `apple-touch-icon.png`
   is exempt: its head link busts it with `?v={{version}}`.
5. **When a project opts in, all four icons ship** — each covers a platform
   surface the others don't.

## Anti-patterns

- ❌ A service worker with an empty `fetch` handler — the install requirement
  it once satisfied is gone, and Chrome ignores the empty handler anyway. It
  is machinery that does nothing.
- ❌ Offline caching or an "app shell" — a second source of truth in the
  client; the server renders the truth.
- ❌ Web push — needs a service worker and scripting; outside this
  architecture.
- ❌ Install-promo banners via `beforeinstallprompt` — JavaScript, and the
  browser already offers install in its own UI.
- ❌ Icon-generator packs (dozens of favicons plus `browserconfig.xml`) — the
  SVG favicon plus these four PNGs cover every platform this stack targets.
- ❌ Rendering the manifest through a template to version its icon URLs — a
  route, a handler, and a content-type, plus `html/template` escaping written
  for HTML and not JSON, all to avoid renaming a file that changes once a
  year.
- ❌ `display: "fullscreen"` or `"minimal-ui"` — the first hides even the OS
  status bar (games territory), the second re-adds browser chrome the install
  was meant to shed. `standalone`, always.

## Facts verified (2026-08-13)

- `fetch()`-handler requirement removed from menu install in Chrome 108
  (mobile) / 112 (desktop); Chrome "mitigated the problem by ignoring empty
  handlers": https://developer.chrome.com/blog/update-install-criteria
- Install criteria — `name`/`short_name`, 192 px and 512 px icons,
  `start_url`, `display`, `prefer_related_applications` false or absent,
  HTTPS; service worker "not a requirement":
  https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable
- `scope` resolves against the manifest URL, no directory restriction; default
  is `start_url` minus filename, query, and fragment:
  https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/scope
- The `theme-color` meta overrides the manifest's `theme_color`:
  https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/theme_color
- Maskable safe zone (radius 40% of width); single-purpose icons recommended:
  https://web.dev/articles/maskable-icon
- `theme-color` with the `media` attribute; not Baseline:
  https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/meta/name/theme-color
- `.webmanifest` absent from Go's built-in mime table, and
  `mime.TypeByExtension` merges `/etc/mime.types`, `/etc/apache2/mime.types`,
  `/etc/apache/mime.types`, and `/etc/httpd/conf/mime.types` on Unix
  (`mime/type_unix.go`): Go 1.26.5, this machine — returns `""` here
- Hex values: throwaway script, oklch → linear sRGB → gamma-encoded hex —
  the oklch → linear-sRGB math shared with the [css-tokens.md](css-tokens.md)
  contrast checks
