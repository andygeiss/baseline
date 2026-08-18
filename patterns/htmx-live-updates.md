# Pattern: Live Updates (htmx)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-15

Keeping a page current while the reader looks at it — a chat room, a queue, a job that
finishes on its own. **The page asks again on a timer; the server never pushes.** One htmx
attribute does it, and the cursor rides in the URL:

```html
<li id="poll" hidden
    hx-get="/rooms/general/messages?since=412"
    hx-trigger="every 3s"
    hx-swap="outerHTML transition:false"></li>
```

## Why polling and not SSE

Server-sent events are the better transport for a busy room, and this baseline does not use
them yet. The reason is the script tag: htmx's SSE support is an **extension**, a second
file to vendor, and [stack/htmx.md](../stack/htmx.md) allows extensions only when a pattern
document mandates one. Polling needs nothing that is not already on the page. Revisit the
trade when the numbers below say so — and that is a decision for this baseline, not for one
project.

## The mechanism: a sentinel row carries the cursor

The element that polls is the last row of the list, and it is also what the response
replaces. That is what makes the cursor advance with htmx core alone — no out-of-band swap,
no extension, no state in the browser. The page renders the list with the sentinel at the
end:

```html
<ul id="messages" role="list">
  <li>… message 411 …</li>
  <li>… message 412 …</li>
  <li id="poll" hidden
      hx-get="/rooms/general/messages?since=412"
      hx-trigger="every 3s"
      hx-swap="outerHTML transition:false"></li>
</ul>
```

The handler answers with the new rows **followed by a fresh sentinel**:

```html
<li>… message 413 …</li>
<li>… message 414 …</li>
<li id="poll" hidden
    hx-get="/rooms/general/messages?since=414"
    hx-trigger="every 3s"
    hx-swap="outerHTML transition:false"></li>
```

`outerHTML` puts all of it where the sentinel was: the messages land in order at the end of
the list, and the new sentinel starts its own timer with the advanced cursor. htmx processes
swapped content automatically, so nothing re-registers anything.

**Nothing new? Answer `204 No Content`.** htmx does not swap a 204, so the old sentinel stays
put and keeps polling with the cursor it has. The quiet case — most cases — costs one indexed
lookup and an empty response.

**Done for good? Answer `286`.** htmx stops polling an element on that status, and it swaps
the response first, so the final content and the stop arrive together. Use it when the
watched thing has ended. Nothing else stops a poll except removing the element from the page.

⚠️ **Both codes depend on the `htmx-config` `responseHandling` array** in the canonical
layout ([stack/html.md](../stack/html.md)), and the 286 rule is not obvious. Traced through
htmx 2.0.10: the cancel sits *inside* the swap branch —
`if (shouldSwap) { if (status === 286) { cancelPolling(elt) } }`. So **286 stops a poll only
while that array counts 286 as a swap**, which the canonical array does through its
`{"code":"[23]..","swap":true}` rule, not by naming 286 anywhere.

**How the array is read is the whole trap: each `code` is an unanchored regular expression,
and the first rule that matches wins.** A status matching no rule does not swap. Three edits
a tidying pass would make, and what each silently costs:

| Edit | What breaks |
|---|---|
| Replace `[23]..` with the codes the app actually returns (`200`, `303`) | 286 then matches nothing, so it does not swap — and the cancel that lives inside the swap never runs. The poll runs forever. |
| Group `422` after `[45]..` | `[45]..` matches `422` first, so the validation flow stops swapping and an invalid form silently does nothing ([htmx-server-rendering.md](htmx-server-rendering.md)). |
| Move `204` after `[23]..` | `[23]..` matches `204` first, so the empty body swaps — wiping out the sentinel that was still polling. |

Narrowing `[23]..` to `2..` is the one edit that looks dangerous and is not: `2..` still
matches `286`. Keep the four rules in the order the canonical layout writes them; that order
is the only thing holding all three flows up.

## Rules

1. **The cursor is a monotonic number, never a timestamp.** Two messages written in the
   same second sort at random by time, so a time cursor either repeats a row or skips one.
   On a list that number is a row id — the `INTEGER PRIMARY KEY AUTOINCREMENT` column from
   [go-sqlite.md](go-sqlite.md). On a region it is a count of pieces the server has
   appended.
2. **The server decides the next cursor,** and sends it back inside whatever it swapped in.
   The browser never computes it.
3. **The response is rows, in order, plus one sentinel.** A response that re-renders the
   whole list throws away the reader's scroll position every few seconds. The one exception
   is the reader's own post — see below. On a list that also pages backwards it throws away
   content rather than a scroll position, and the sentinel is no longer the only thing at
   the ends of that list — see [htmx-lists.md](htmx-lists.md).
4. **The polled route is htmx-only, so it MUST redirect a plain request.** Answer `303 See
   Other` back to the page when `HX-Request` is absent. A plain reader is not missing a
   feature: the full page already renders every row, and reloading it *is* the no-htmx
   version of this pattern.
5. **No indicator on a poll.** Every request over 100 ms shows one
   ([stack/htmx.md](../stack/htmx.md)), and a background poll is the one exception. An
   indicator that blinks every three seconds trains the reader to ignore it. Set
   `hx-indicator` on the message *form*, which a person started.
6. **Opt the swap out of view transitions** (`transition:false`). Messages arriving on a
   timer are the rapid-fire case in [css-motion.md](css-motion.md).
7. **Never rate limit the polled route.** The limiter in
   [go-auth-sessions.md](go-auth-sessions.md) guards login and registration; pointing it at
   a route every open tab hits on a timer locks out real readers.
8. **Authorize every poll like any other read.** It is a normal request with a session
   cookie, so `requireAuth` covers it — and a cursor is not a capability, so the handler
   still checks that this reader may read this room.

## When the reader adds something themselves

A poll is not the only thing that changes the list, and the reader's own message must not
arrive twice or push the cursor past somebody else's.

**Swap the whole region on send, and only on send.** The form targets a wrapper holding the
list, the poller, and itself; the answer re-renders all three from one read. The cursor and
the form then come from the same number, so they cannot drift, and the sender's message
needs no special path.

That is the opposite of rule 3, and the difference is who asked. The reader pressed Send, so
they are looking at the bottom of the list and expect it to change. A poll doing the same
thing every three seconds would move the ground under somebody who is reading.

## When the polled thing is not a list

The sentinel row is a *list's* mechanism: the cursor advances because the last row is
what the response replaces. Some polled things have no last row — a job reporting
progress, one status line, a reply being written a sentence at a time. The part that
changes is the whole of it.

**Then poll the region and swap the region.** The poller sits inside it and targets it:

```html
<div id="job">
  <p>… 3 pieces so far …</p>
  <span hidden
        hx-get="/jobs/7?since=3" hx-target="#job"
        hx-swap="outerHTML transition:false" hx-trigger="every 5s"></span>
</div>
```

The answer is the region again, carrying a fresh poller with the advanced cursor. **Rule
3 is the only one that gives way,** and it gives way for its own stated reason: it
protects a reader's place in a long list, and a few lines somebody is watching change
have no place to lose. Everything else stands — the server still decides the next cursor
and sends it (rule 2), 204 still leaves the poller alone, 286 still stops it,
`transition:false`, no indicator, and 303 to the page for a plain request.

**Appended and never rewritten is what makes rule 1's count work** — pieces produced,
lines logged. A count over anything the server edits in place hands the same piece over
twice, and that is not merely wasted bytes: audio sent twice is played twice.

**One second is the exception, and only for a region somebody consumes as it arrives.** The
interval rule below still applies — pick it from how stale the reader may be — and a reply
being read aloud is stale the moment the next sentence exists. A progress region is not
one of those: five seconds, like the snippet above.

## The handler

```go
// pollView is what the block above needs: the rows to add, and the room and
// cursor the new sentinel is built from. The rows alone are not enough — the
// sentinel carries a URL.
type pollView struct {
	Room     domain.Room
	Messages []domain.Message
	Since    int64
}

func (a *App) roomMessages(w http.ResponseWriter, r *http.Request) {
	// Rule 4: this route is an optimization of "reload the page", so a reader
	// without htmx is sent to the page rather than handed a fragment.
	if r.Header.Get("HX-Request") != "true" {
		http.Redirect(w, r, "/rooms/"+r.PathValue("slug"), http.StatusSeeOther)
		return
	}
	// Rule 8: a normal read, authorized like any other. requireAuth put the
	// reader in the context; a room only some people may see is checked here,
	// because a cursor is not a capability.
	room, ok := a.room(w, r)
	if !ok {
		return
	}
	since, err := strconv.ParseInt(r.URL.Query().Get("since"), 10, 64)
	if err != nil || since < 0 {
		a.clientError(w, r, http.StatusBadRequest)
		return
	}

	msgs, err := a.messages.Since(r.Context(), room.ID, since)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	if len(msgs) == 0 {
		// This response bypasses the render helper, so it adds the Vary header
		// itself — an un-Vary'd variant is cacheable against the wrong mode.
		w.Header().Add("Vary", "HX-Request, HX-Boosted")
		w.WriteHeader(http.StatusNoContent) // the sentinel survives, cursor intact
		return
	}
	a.render(w, r, http.StatusOK, "room.html", "poll-update", pollView{
		Room:     room,
		Messages: msgs,
		Since:    domain.LastSeq(msgs, since),
	})
}
```

The store's `Since` caps how many rows it returns, so a reader who left the tab open over
lunch comes back to one bounded response. `LastSeq` is the cursor rule in one place: the
highest sequence number in hand, or the one the reader already had when nothing came back.
Computing it in the handler is what keeps rule 2 true.

## What this costs, and when to stop

One open tab is one request per interval. **A hundred readers at three seconds is about 33
requests a second**, almost all of them 204s — nothing for a Go binary in front of an
indexed SQLite read, which is why the simple mechanism wins at this size.

Two numbers say the trade has flipped: the empty-response share stops being most of them
(readers are getting stale views between polls), or the request rate starts to matter next
to everything else the app serves. Both are arguments for server-sent events, and both
belong in a pull request against this baseline.

Pick the interval from how stale the reader may be, not from how fast the server is: a chat
room reads well at 3 s, a job status at 5 s, a dashboard at 30 s, and a reply somebody is
listening to at 1 s.

## What polling cannot do

**It cannot scroll.** New rows arrive below the fold, and moving the viewport needs
JavaScript. The usual workaround — a `column-reverse` flex list that pins itself to the
bottom — buys that scroll by putting the newest message first in the markup, which is the
order a screen reader then announces. **Correct reading order wins over automatic
scrolling.** Do not take that trade without recording it as a waiver. The one free win:
after a plain-form post, redirect to `/rooms/general#bottom` so the browser lands on the
newest row by itself.

**It cannot pause in a hidden tab.** The obvious guard is an htmx trigger filter,
`every 3s [document.visibilityState==='visible']` — and htmx evaluates that expression, so
it needs the `'unsafe-eval'` that [security-headers.md](security-headers.md) forbids
outright. Background tabs keep polling; budget for it in the cost model above, because that
is the whole mitigation.

## Anti-patterns

- ❌ `hx-trigger="every 1s"` on a list because it feels responsive. It triples the cost
  model and no reader notices. The exception is a region consumed as it arrives, and
  *When the polled thing is not a list* makes that case.
- ❌ A cursor the browser keeps (in the URL hash, in a data attribute it edits). That is
  client-side state, and the server is the source of truth.
- ❌ Polling a route that returns the full page. `hx-select` makes it look cheap; the server
  still rendered everything.
- ❌ `hx-swap-oob` on the poller. htmx lifts every out-of-band element out of a response
  before swapping what is left, so a poller marked that way is pulled out of the region it
  belongs to — and on the send path above, it is swapped against the copy being replaced.
  The sentinel is the swap target, not an out-of-band passenger.
- ❌ An htmx extension for SSE or WebSockets, added to one project. Either this document
  changes for everyone or it does not change.
