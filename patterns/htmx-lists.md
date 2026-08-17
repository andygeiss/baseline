# Pattern: Long Lists (htmx)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-17

Every project renders a list, and every project re-decides the same two things: how the
page asks for more, and how the query finds it. Both are settled here.

## Keyset, never OFFSET

**`LIMIT … OFFSET` is a correctness bug before it is a speed one.** The offset counts rows
that are still moving. Insert one row at the top between page one and page two and the
reader sees row 20 twice; delete one and a row they never saw is gone. Count from a place
in the data instead — the last row already on the page:

```sql
-- The actor predicate is not optional here (go-authorization.md rule 5). The
-- row-value comparison is one operation, so SQLite can walk the index straight
-- to the cursor instead of filtering after it.
SELECT id, title, created_at
FROM items
WHERE user_id = ?
  AND (created_at, id) < (?, ?)
ORDER BY created_at DESC, id DESC
LIMIT ?
```

- **The sort key ends in a unique column.** `created_at` alone is not a cursor: two rows
  in the same second order at random, so one repeats and one disappears. The `id` term is
  what makes the position exact — the same reason the poll cursor is a row id
  ([htmx-live-updates.md](htmx-live-updates.md) rule 1).
- **When the sort key is already unique, the cursor is one column and the row value goes
  away.** A table sorted by its `INTEGER PRIMARY KEY AUTOINCREMENT` — which is every table
  a poll reads — pages with `AND seq < ?` and needs no pair at all. Reach for the row
  value only when the thing people sort by is not unique.
- **The `ORDER BY` and the comparison face the same way.** `DESC` with `<`, `ASC` with
  `>`. Mixed, the query returns the rows it was walking away from.
- **An index has to cover the sort key; its direction does not have to match.** SQLite
  reads an index backwards just as happily, so `items(user_id, created_at, id)` serves
  both directions — `EXPLAIN QUERY PLAN` shows the same `SEARCH … USING INDEX` and no
  temp b-tree either way. What is not optional is having one: without it, keyset is a
  full scan with extra arithmetic.
- **Ask for one more row than you show.** `LIMIT n+1`, then trim the extra before
  rendering: its presence is the answer to "is there another page", and it costs nothing
  next to a second `COUNT(*)` over the same table.

## The control is the page state

No page numbers, no state in the browser. **One list item is the control, and it sits at
the far end from where new rows arrive** — which end that is depends on how the list is
sorted, and getting it wrong puts it on top of the poller:

```html
<ul id="items" role="list">
  <li>… newest …</li>
  <li>… </li>
  <li class="more">
    <a href="/items?before=2026-08-17T09:14:02Z&amp;id=412"
       hx-get="/items?before=2026-08-17T09:14:02Z&amp;id=412"
       hx-target="closest li"
       hx-swap="outerHTML">Show older</a>
  </li>
</ul>
```

That list is newest-first, so it grows at the top and the control is its **last** item.
The handler answers with the next rows **followed by a fresh control**, carrying the
cursor of the last row it sent. `outerHTML` on the enclosing `<li>` puts all of it where
the control was, so the older rows land at the end of the list in order.

**An oldest-first list is the mirror image, and it is the one that composes with a poll.**
A chat grows at the bottom, and [htmx-live-updates.md](htmx-live-updates.md) already puts
the poller there as the last row — so the control is the **first** item, and the answer is
the fresh control **followed by** the older rows, which is again the list's own order.
Both cannot be the last row, and a list that tries loses one of them.

**The list ends when the control does not come back.** The last page answers with rows
alone; there is nothing to remove and nothing to disable.

**It works with htmx switched off.** The control is an `<a href>` with the same URL, so a
plain click navigates to a full page of that slice — the handler is dual-mode like any
other ([htmx-server-rendering.md](htmx-server-rendering.md)). This is why the cursor rides
in the query string and not in a header: one URL serves both readers, and it can be
bookmarked and shared.

## When the same list also polls

A chat room grows at one end and is paged at the other, and the two mechanisms are easy to
cross. They are **two cursors, and they MUST NOT share a parameter name**: the poll
advances `since` forward at the arrival end, the pager walks `before` backward at the far
end. Beyond that:

- **A poll that re-renders the list root throws away every page the reader loaded.** Rule
  3 of [htmx-live-updates.md](htmx-live-updates.md) already forbids it; on a paged list the
  cost is not a lost scroll position but lost content.
- **A paged list decides what a send does to the pages already loaded, and says which.**
  The whole-region swap — the exception in *When the reader adds something themselves* —
  rebuilds the region from one read, which is the newest page: the reader snaps back to
  the bottom and everything they had loaded is gone. **For a chat that is what pressing
  Send is expected to do.** For a list somebody works through rather than talks in, it is
  losing their place, and the send should append at the arrival end instead. Pick one and
  write it in the README, beside the other choices a pattern leaves open.

## Filtering and sorting reset the cursor

A filter or a sort change redefines what "before this row" means, so **carrying the old
cursor across one is how a reader lands on an empty page two.** Drop it: a changed filter
starts at the top. Filters live in the query string beside the cursor, and the control
that comes back carries them all, or the second page quietly loses them.

## Anti-patterns

- ❌ `OFFSET`, and page numbers, which are `OFFSET` wearing a hat.
- ❌ A total count rendered on every page. `COUNT(*)` over a growing table, per request,
  to print a number nobody acts on.
- ❌ Infinite scroll (`hx-trigger="revealed"`). It takes the footer away from everyone,
  strands keyboard and screen-reader users in a list with no end, and gives the reader no
  way back to where they were. A control they press is the whole difference.
- ❌ The cursor in a `data-` attribute or the URL hash. That is client-side state, and the
  server is the source of truth.
- ❌ Rendering everything and filtering in CSS. The row still crossed the wire, and a
  hidden row is still in the accessibility tree.
