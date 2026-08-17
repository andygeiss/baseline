# Pattern: Times and Dates

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-17

No JavaScript means no browser clock and no browser time zone. Every other stack reads
both from the client; here **the server decides what time it is for the reader, and it has
to decide on purpose.** [go-sqlite.md](go-sqlite.md) picks the column. This document is
everything after the read.

## The template never sees a `time.Time`

That is the whole shape. A `time.Time` in a template invites `{{.CreatedAt.Format …}}`,
which renders in whatever zone that value happens to carry — rule 1 below is about which
zone that turns out to be — in one of the dozens of places a template mentions a date.
Format once, in the handler, into a view struct:

```go
// Stamp is how a moment reaches a template. Building one is the only place in
// the app that formats a time, so it is the only place that names a zone.
type Stamp struct {
	ISO      string // machine-readable UTC, for the <time datetime> attribute
	Absolute string // "17 Aug 2026, 11:14 CEST" — what the reader sees
	Relative string // "3 minutes ago", where the page earns it
}

func NewStamp(t time.Time, loc *time.Location, now time.Time) Stamp { … }
```

```html
<time datetime="{{.Created.ISO}}" title="{{.Created.Absolute}}">{{.Created.Relative}}</time>
```

The rules — all MUST:

1. **Nothing calls `Format` without naming a zone.** `t.In(loc).Format(…)`, never
   `t.Format(…)` on a value whose zone nobody chose. Bare `Format` renders in whatever
   zone the value happens to carry, and
   which zone that is depends on how it was read: `time.Parse` of an RFC 3339 string
   carries the offset written in the string, and **`time.Unix` returns a *local* Time**.
   [go-sqlite.md](go-sqlite.md) lets a project store Unix integers, so that second path is
   live: the same row renders in the developer's zone on their laptop and in UTC in the
   container, and no test notices, because the test runs on the laptop.
2. **`time.Local` is never named in application code.** Not in a handler, not in a store,
   not in a template function.
3. **Every rendered moment carries `<time datetime>` with the UTC value.** The visible
   text may be relative, rounded, or in words; the attribute stays exact and
   machine-readable.
4. **`now` is a parameter, not a call.** `NewStamp` taking the current time is what makes
   "3 minutes ago" testable without waiting three minutes.

**Storing is not rendering.** A store writing `time.Now().UTC().Format(time.RFC3339)` has
named its zone and is recording when a write happened; nothing above is about that. These
rules are about what a person reads.

## Which zone the reader gets

Three answers. Pick one, write it in the README, and stop re-deciding per page:

| Answer | What it costs | Right when |
|---|---|---|
| **One zone for the whole app**, from `Config`, with the abbreviation always shown ("11:14 CEST") | Wrong for anyone elsewhere, but never ambiguous | A team tool, a shop, anything with one location |
| **The reader's zone, stored** — a `<select>` on the profile, defaulted at signup | One column, one setting page, one more thing to test | Users in more than one country |
| **No clock times at all** — dates, and relative times for anything recent | Ambiguous near midnight; "yesterday" may be today | Content where the hour carries no meaning |

**A clock time with no zone marker is the one thing none of the three allows** — which is
why the third answer drops clock times rather than printing bare ones. "11:14" is a
different moment for every reader; "11:14 CEST" is one moment for all of them.

## The container has no time zone database

`time.LoadLocation` reads `/usr/share/zoneinfo`, which a minimal image does not have — so
the zone the config names loads fine on the developer's machine and fails at boot on the
server. Embed the database in the binary instead:

```go
import _ "time/tzdata" // ~450 KB, and what makes LoadLocation work where the
                       // system database is absent
```

Load every zone the config names **at boot**, next to the rest of validation
([go-config.md](go-config.md)): a bad zone name is then one startup error naming the fix,
not a nil location three weeks later.

## Relative time is stale the moment it is sent

The server renders "3 minutes ago" and the page may sit open for an hour. Use it only
where the page already refreshes on its own
([htmx-live-updates.md](htmx-live-updates.md)), and always with the exact moment beside
it: `title` for a person, `datetime` for a machine. Everywhere else, render the absolute
time.

Round down, and stop at a day. "2 hours ago" is useful, "just now" is friendly, and
"4 months ago" is a date the reader has to work out — past a day, show the date.

## A day is a zone, not a column

Grouping by day is where UTC storage leaks into the UI. An event at 00:30 CEST is filed
under yesterday if the database does the bucketing:

```sql
-- ❌ 'localtime' is the server's zone — UTC in the container, the developer's
--    zone on their laptop. The same query, two answers.
SELECT date(created_at, 'localtime') AS day, count(*) FROM events GROUP BY day;
```

Compute the boundaries in Go, in the reader's zone, and pass them as parameters
(`WHERE created_at >= ? AND created_at < ?`), written in the column's own format so the
comparison is the one the index does. That stays correct across a daylight-saving change,
which a fixed offset does not.

## Testing

- **Format tests name a zone and a fixed instant**, and assert the exact string. A test
  that formats `time.Now()` asserts nothing.
- **Add the awkward instants to the table:** the hour that repeats when clocks go back,
  the hour that does not exist when they go forward, and a moment just after midnight in
  a zone ahead of UTC.
- **Anything on a timer uses `synctest`**, never `time.Sleep`
  ([go-testing.md](go-testing.md)).
- **The `TZ` check.** Running the suite once with `TZ=Pacific/Auckland go test ./...`
  finds every implicit `time.Local` at once, because the process starts in that zone.
  Worth doing when the rule is first adopted, and after any sweep over rendering code.

## Anti-patterns

- ❌ `time.Now()` inside a domain function, or anywhere its result is compared or
  rendered. Pass the moment in; that is what makes an expiry and "3 minutes ago" testable.
  A store stamping `created_at` from the clock is not this.
- ❌ Storing a wall-clock string in the user's zone. The zone changes twice a year and the
  stored value does not.
- ❌ A `template.FuncMap` entry that formats a time. It looks like the fix and it puts
  formatting back in the template, in a function with no zone argument.
- ❌ Guessing the zone from `Accept-Language` or the IP address. Both are wrong often
  enough to be worse than one honest app-wide zone.

## Facts verified (2026-08-17)

- `Format` renders in the time's own location, and `time.Unix` "returns the local Time
  corresponding to the given Unix time" — which is why the storage choice decides whether
  a bare `Format` differs between machines: https://pkg.go.dev/time#Unix
- `time.Parse` uses the offset in the string, and UTC when the layout carries no zone:
  https://pkg.go.dev/time#Parse
- Importing `time/tzdata` "will increase the size of a program by about 450KB", and it is
  what makes `LoadLocation` work where the system database is absent:
  https://pkg.go.dev/time/tzdata
- SQLite's `localtime` modifier converts to the zone of the *process running SQLite*:
  https://sqlite.org/lang_datefunc.html
