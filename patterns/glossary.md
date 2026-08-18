# Pattern: Glossary (GLOSSARY.md)

**Tier 3** (taste — choosing is the rule, so no waiver is needed) · Last verified: 2026-08-16

Once a project keeps the file, how it is written is tier 2: that part is not a
per-project choice.

`GLOSSARY.md` at the repo root is the project's word list: one entry per concept
this project owns, and the words it turned down. It settles names and nothing
else — a reader who wants to know how something works reads the code.

The list exists for the next person to write here — usually an AI coding agent,
starting from an empty memory. Without a word list the agent picks a
reasonable synonym, and the project ends up with `Room` in the domain,
`channel` in the templates, and "thread" on the buttons. One list, read before
the first identifier, keeps the code, the UI, the URLs, and the commit messages
saying the same word.

**Opt-in per project.** A project whose vocabulary is the baseline's plus plain English
writes nothing down. The moment one concept has two names in the code, that
project has a glossary — and its README links the file in one line, the way it
links this baseline. A word list nobody is pointed at is one nobody reads.
**A library never has one:** its package doc comment is its word list, and
pkg.go.dev renders that ([go-library.md](go-library.md)) — a second list in the
repo is one no consumer ever sees.

## The file

The file Go Chat ships — the reference implementation for this baseline. Seven
terms, flat: one cohesive area needs no subheadings.

````markdown
# Glossary: Go Chat

The words this project uses. One word per concept; where people say it more
than one way, the runners-up sit under _Avoid_. Wherever a concept shows up —
in the code, on screen, in a URL — it shows up under the word listed here.

**Attachment** — the one file a message may carry. It is stored under a
generated id and the type its bytes turn out to be, never the name or the type
the browser claimed. _Avoid: upload, file, media._

**Author** — the user a message is credited to. _Avoid: poster._

**Invite code** — the shared secret somebody must type to make an account, when
the deployment sets one. _Avoid: access code, signup code._

**Message** — one thing somebody said in a room. Never edited, and deleted only
when its author's account is. _Avoid: post._

**Outbox** — the table a message waiting to be emailed sits in. A handler writes
to it and one background sender drains it, so nothing is ever sent inside a
request. _Avoid: mail queue, job queue._

**Reset link** — the one-hour, single-use address that lets somebody set a new
password. Only the SHA-256 of its token is stored, so the link itself exists in
one place: the message that carried it. _Avoid: recovery link, magic link._

**Room** — one conversation. Everything posted lives in exactly one room.
_Avoid: channel, thread._

**Seq** — the number that identifies a message and fixes its place in the room.
It only grows, so it is also the cursor a reader polls from.
_Avoid: message id, offset._

**Slug** — the ASCII address a room lives at, `/rooms/<slug>`. A room's name is
what people read; its slug is where the room is.

**Token label** — the note a person writes on a machine token ("laptop", "build
server") to tell their tokens apart later. _Avoid: token name, token
description._
````

Three things in that file are the pattern, not the chat app:

- **Every entry is a noun, and the first clause says what the thing is.** "Room
  — one conversation", not "Room — groups messages by topic and shows them in
  order". Behavior lives in the code and its tests.
- **The list stops at what Go Chat owns.** There is no entry for *cursor*,
  *session*, or *machine token* — those are the baseline's words, defined once
  in [htmx-live-updates.md](htmx-live-updates.md) and
  [go-auth-sessions.md](go-auth-sessions.md). *Seq* earns its entry because the
  baseline calls for a cursor and Go Chat picked the number that is one;
  *Token label* earns one because the baseline names the token and the project
  names the note on it.
- **_Avoid_ carries the runners-up.** It is the half an agent greps: reading
  "Avoid: channel, thread" is what stops the synonym from arriving in the next
  template.

[STYLE.md](../STYLE.md) governs the entries — plain words, one idea per
sentence, the point first. Two of its Documents rules do not reach this file: a
word list has no command to open with, so the words open it; and the subheadings
allowed by rule 4 below are domain areas, which is what a reader of a word list
scans for.

## Rules

1. **One word per concept, and the losers are named.** Pick the best word, then
   list under _Avoid_, in the same entry, every synonym that has shown up in the
   code or the docs. An entry with no _Avoid_ line is fine — a concept that
   quietly tolerates two words is not, and that is the entry the glossary exists
   for.
2. **One or two sentences, saying what the thing IS.** Start with the noun
   phrase that defines it. A definition that describes what the thing does has
   drifted into design documentation; behavior belongs in the code and its
   tests.
3. **Only this project's words.** Two exclusions cover almost everything an
   eager glossary collects:
   - **General programming concepts** — timeout, retry, handler, migration,
     validation, idempotent. The project uses them with their textbook meaning,
     and a reader who does not know them needs a textbook, not this file. A
     general word the project gave a specific job is different: *slug* is a web
     term everywhere, but *which* of a room's two names goes in the URL is this
     project's decision, so it earns an entry.
   - **Baseline vocabulary** — port, adapter, fake, machine token, surface
     style, cursor. These are defined here, once, for every project
     ([go-ports-adapters.md](go-ports-adapters.md),
     [go-auth-sessions.md](go-auth-sessions.md),
     [css-surfaces.md](css-surfaces.md),
     [htmx-live-updates.md](htmx-live-updates.md)). Copying a definition into a
     project creates a second one, and the copy is what goes stale.

   The test before adding a term: **name the wrong word it prevents.** If you
   cannot, the term is not carrying its weight.
4. **Alphabetical, and grouped only when the clusters are already there.** This
   is a file people look words up in, so the words sit in the order a reader
   expects. A flat list is the default: add subheadings when the file covers two
   or more plainly separate areas and a reader would otherwise scan past what
   they came for — billing and scheduling, say. Never invent headings to fill a
   template: "Core concepts" and "Other" tell the reader nothing.
5. **The glossary and the code stay lockstep, same commit.** A term is a
   promise about identifiers: `Room` the term is `domain.Room` the type, `room`
   the route word, "Room" the button label. Wherever the concept shows up, it
   shows up under this word. Renaming the concept renames every one of them and
   this file in one commit — the discipline
   [design-system.md](design-system.md) rule 3 uses for `DESIGN.md`. When the
   code and the glossary disagree, that is a defect, not a choice to make.
   When a rejected word survives where renaming is expensive — a database
   column, a released JSON field — the entry says so in its _Avoid_ line.
   Silence there reads as an oversight, and the next reader spreads the word
   back.

## Anti-patterns

- ❌ A paragraph explaining how the thing works ("Room — validates its name,
  stores messages, and pages them back 200 at a time") — that is design
  documentation with a word list stapled to the front. Name the concept in two
  sentences; the code owns the mechanism.
- ❌ Restating baseline vocabulary (rule 3) — a project's definition of *port*
  or *cursor* is a second source of truth that nobody updates.
- ❌ An onboarding doc in disguise: acronym expansions, stack facts, "what is
  htmx". [stack/htmx.md](../stack/htmx.md) explains the stack; the project
  README explains the project.
- ❌ Vocabulary for features nobody has built — a word enters the list in the
  commit that first uses it, not before.
- ❌ A glossary the code contradicts — an unmaintained word list is worse than
  none: the next agent trusts it and renames the wrong thing.
