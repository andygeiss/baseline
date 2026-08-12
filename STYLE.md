# House Style: Writing for Humans

**Last verified: 2026-08-12**

This document governs everything we write for people: README files and docs,
commit messages, Go source comments, and prompts for LLMs (AI language
models). One bar applies to all of it:

> **A smart 10-year-old could follow it.**

That is a clarity bar, not a license to be childish. The technical content stays
exact. The sentences get simple. When precision and plainness seem to conflict,
keep the precision — and explain the hard part in plain words right next to it.
This baseline's own prose holds the same bar; its structure (a navigation README,
category headings) follows its own protocol, not the Documents rules below.

## The test

Read what you wrote out loud, once.

- Had to re-read a sentence? Rewrite it.
- Hit a word a 10-year-old would ask about? Use a plainer word, or explain it
  where it first appears.
- Found the point in the middle of a paragraph? Move it to the first sentence.

## Rules for all writing

- **One idea per sentence.** If reading it aloud takes more than one breath,
  split it.
- **Plain words.** Use the everyday word when it means the same thing (MUST):

  | Not this | This |
  |---|---|
  | utilize, leverage | use |
  | in order to | to |
  | prior to | before |
  | subsequently | then |
  | functionality | feature |
  | facilitate | help, let |
  | instantiate | create |
  | terminate | stop |

  Terms of art (goroutine, mutex, CSRF, idempotent) are not on this list — they
  are precise, so keep them. The table bans a word only in its everyday sense:
  when the word is itself the term of art (TLS termination, a signal's
  terminate disposition, a process terminating on SIGTERM), keep it too.
  Gloss a term of art at first use when the document's audience may not know
  it: user-facing docs explain; this baseline and its checklists, written for
  engineers and AI agents, do not need to.
- **Point first.** State the conclusion, then the reasons. Never make the
  reader hunt for what you are telling them.
- **Active voice with a named actor.** "The server closes idle connections
  after two minutes" — not "idle connections are closed".
- **Show, then tell.** Prefer a concrete example or a before/after pair to
  paragraphs of description.
- **No filler.** Delete "it should be noted that", "basically", "simply",
  "please note", "as mentioned above" when they only pad the sentence. A word
  doing real work stays: "the detail is simply unexported" means *nothing more
  than* unexported.

## Documents (READMEs, docs, design notes)

- The first two sentences say what this is and who it is for.
- A runnable example appears on the first screen. Readers trust commands,
  not claims.
- Headings state facts or actions ("Install", "Why there is no config file") —
  not categories ("Overview", "Miscellaneous").
- File trees list entries alphabetically — case-insensitive, files and
  directories interleaved — so every tree is mechanically checkable against
  the real directory. Everything else that mentions files orders by meaning:
  a topology sketch by data flow, a "Required reading (in order)" list by
  dependency.
- One primary audience per document. When users and contributors need
  different things, split the document.

**Before:** "This functionality facilitates application configuration via
environment variables prior to initialization."
**After:** "You configure the app with environment variables. Set them before
it starts."

## Commit messages

Semantic commits, always: `type(scope): subject` — the scope optional, the
subject imperative and lowercase ("add", not "added"), ≤ 72 characters, no
trailing period.

```
feat(games): add rematch from the result page

The result page linked back to the lobby, so a rematch cost three clicks.
POST /games/{id}/rematch creates the new game and 303s into it.
```

- **Six types.** `feat` (new behavior), `fix` (corrected behavior), `docs`,
  `refactor` (same behavior, restructured), `test`, `chore` (housekeeping:
  deps, Makefile, CI). A commit that needs two types is two commits.
- **`!` marks a breaking change** (`feat!: drop the CSV export`). For a
  released module the type encodes the semver decision
  ([patterns/go-library.md](patterns/go-library.md)): `fix` is a patch,
  `feat` a minor, `!` a major — `git log` answers the version question before
  tagging.
- **The body answers why**, after a blank line, when the subject alone does
  not — the same rule as Go source comments: the diff says what.
- **No enforcement tooling.** commitlint and hooks check format, not sense;
  the reviewer checks both.

## Go source comments

- **Code says what. Comments say why.** A comment that restates the code is
  noise. A comment that explains a decision, constraint, or trap is gold. If
  code needs a comment to explain *how* it works, first try to simplify the
  code.
- Doc comments follow the godoc convention (full sentences, starting with the
  identifier's name) — and then this document: a newcomer who knows Go but not
  this project MUST be able to understand them.
- MUST NOT: narrate the next line, keep changelogs in comments, or leave
  commented-out code behind.

```go
// Bad: narrates what the code already says.
// Loop over the users and add them to the map.

// Good: states the constraint the code cannot show.
// Process users in ID order so reruns produce byte-identical output.
```

## LLM prompts

A machine reads the prompt, but the same style wins: models follow plain,
concrete instructions better than clever ones.

- One instruction per sentence, imperative mood: "Return JSON. Use only these
  fields: …"
- Show one example of the desired output. It beats every adjective — "concise"
  and "high quality" are vague to a model; an example is exact.
- State the audience and the bar inside the prompt: "Write so a smart
  10-year-old could follow it."
- Order the prompt top-down: context → task → constraints → output format.
- A one-line role ("You are a Go code reviewer.") is enough. Stacked
  superlatives and magic phrases add tokens, not quality.
- Prompts are code: keep them in version control next to the code that sends
  them, and review them like code.
