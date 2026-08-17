# Pattern: LLM Adapter (Go)

**Last verified: 2026-08-17**

A language model is somebody else's system reached over HTTP, so
[go-ports-adapters.md](go-ports-adapters.md) already governs the shape: a small
port the consumer declares, an adapter that translates, a hand-written fake.
This document is what that shape looks like when the system on the other side is
a model — the parts that are the same for every vendor, and the three traps that
are specific to models and cost you a product bug rather than a compile error.

**Assume every service grows one.** This is not an exotic integration to reach
for twice a year; it is the default shape for the AI capability a project adds
to otherwise deterministic code. Read it before the first request, not after.

## What this document does not own

**Model IDs, request fields, beta headers, pricing, and token limits are not
here, and MUST NOT be copied here.** They change every few weeks; this document
is re-verified every ninety days. A pin written here is a wrong answer with a
long shelf life.

> **The `claude-api` skill is the source of truth for anything on the wire.**
> Load it before writing or changing a request, every time — including when you
> are "just" changing a model ID or adding a field. It carries the current model
> IDs, the thinking and effort parameters, the beta headers, and the migration
> notes. Your training data does not.

That skill wins over this document on every fact it covers. This document owns
the shape around it: where the prompt lives, what the port says, what the
adapter translates, and what the test pins.

## The shape

```
project/
├── cmd/server/main.go        ← picks which adapter, the only file naming both sides
└── internal/
    ├── app/
    │   ├── reply.go          ← the port, beside the feature that needs it
    │   └── reply_test.go     ← the fake, and the feature's tests
    ├── domain/
    │   ├── message.go        ← the types and the sentinels
    │   └── prompt.go         ← the system prompt: a product rule, not a vendor detail
    ├── anthropic/            ← adapter: the only package that knows Anthropic's API
    └── openai/               ← adapter: any server speaking the OpenAI chat shape
```

Each adapter imports `internal/domain` and nothing else of yours, and
`go list -deps` proves it ([go-ports-adapters.md](go-ports-adapters.md)).

## The port says what the app needs, in the app's words

```go
// internal/app/reply.go

// Assistant answers the conversation so far.
//
// Reply returns domain.ErrRefused when the model declines to answer. Every
// other error is treated as transient.
type Assistant interface {
	Reply(ctx context.Context, history []domain.Message) (string, error)
}
```

1. **One method, domain types, no vendor words.** No `max_tokens`, no
   `temperature`, no `*http.Response`, no model ID. A port that names the
   vendor's parameters is the vendor's SDK wearing a costume, and swapping the
   model becomes a change to every caller.
2. **Every knob stays inside the adapter** — model, effort, token ceiling,
   timeouts, retries, headers. `main` chooses *which* adapter; the adapter
   chooses how it talks.
3. **The port's doc comment names every error a caller branches on.** That
   sentence is the contract the fake and the adapter both have to meet.

## The prompt is a product rule, so it lives in `domain`

```go
// internal/domain/prompt.go

// SystemPrompt is how the assistant speaks. It lives here, next to the types
// both adapters use, because it is a product rule rather than a detail of any
// one vendor's API.
const SystemPrompt = `...`
```

4. **One prompt, in `domain`, shared by every adapter.** Put it in the adapter
   and the second adapter gets a copy, the two drift, and the product answers
   differently depending on a flag nobody connects to the symptom.
5. **The conversation's required shape is domain's too.** Every chat model wants
   the user first, and a transcript reaches a worse shape on its own: a turn that
   fails after the question is stored leaves the question unanswered, so the next
   turn puts two user messages in a row. What each vendor then does with that is
   not this document's to promise — one rejects it, the next merges the two turns,
   a local chat template silently builds a malformed prompt — and *none* of those
   is the conversation you meant to send. Normalise once, in `domain`, and let
   every adapter call it:

   ```go
   // internal/domain/message.go

   // Alternating returns the history the way a model has to be given it: the
   // user speaks first, and from there the two take strict turns. Two turns by
   // one speaker are one turn to the model, so they are joined, not dropped.
   func Alternating(history []Message) []Message
   ```

   Test it against the failure that produces it — an unanswered question — not
   only against a tidy transcript.
6. **Prompts are code** ([STYLE.md](../STYLE.md) *LLM prompts*): version
   controlled, reviewed, and written to the same bar as everything else.

## The adapter translates, in both directions

7. **A refusal is a sentinel, not an error.** A model that declines to answer is
   a normal outcome the caller branches on, so it becomes
   `domain.ErrRefused` and the product says something out loud instead of
   showing a 500. Each vendor signals it differently — the `claude-api` skill
   names the current field per vendor — and the adapter is where that vendor
   word disappears.

8. **Check the refusal before you read the text.** A declined request is a
   **successful HTTP 200** whose content is empty or partial. Code that reaches
   for the first content block before checking the stop reason panics or returns
   nonsense on the one path that is hardest to reproduce:

   ```go
   // refusalStopReason is the vendor's word for "the model declined", and this
   // is the only line in the project that spells it — rule 7's "the adapter is
   // where that vendor word disappears", as one constant. The value comes from
   // the claude-api skill and is pinned by the wire test below, never from
   // memory.
   const refusalStopReason = "refusal"

   // The check comes before reading the text: a declined request answers 200
   // with no text at all, and indexing into that is the bug this ordering
   // prevents.
   if out.StopReason == refusalStopReason {
       return "", domain.ErrRefused
   }
   ```

   Where the vendor offers a **server-side fallback** — a declined request
   answered by another model inside the same call — prefer it to your own retry:
   it costs one round trip and no state. The skill has the current parameter and
   its beta header. Two traps it documents and this sentence cannot: the header
   and the parameter shape are a matched pair, and mixing a header from one form
   with the body of another is a 400.

9. **Everything else is transient.** Wrap it with what you were doing and let
   the caller decide ([go-errors-logging.md](go-errors-logging.md)). Transport,
   timeouts, body caps, and the `drainAndClose`/`statusError` helpers are
   [go-http-client.md](go-http-client.md)'s job and do not change here.

## The visible text is the product

This is the trap that has no compile error and no failing test — only a reply
that reads wrong.

10. **A reasoning model can write its reasoning into the answer.** The text you
    render, speak, or store is the product; a leaked scratchpad — "Here's my
    thinking process: 1. Analyze the user input…" — is a product bug that ships
    silently. It happens from **both** directions, which is why one rule cannot
    cover it:

    - **A frontier model with thinking switched off** may write longer reasoning
      into the visible response. Leave adaptive thinking **on** and control cost
      with the effort setting instead. On current models this is also the
      cheaper answer: a low effort level costs less than a disabled-thinking
      request that rambles.
    - **A local reasoning model with thinking switched on** writes its
      scratchpad into the reply. Ask its chat template to turn thinking off. A
      server that does not know the field ignores it.

    Whichever you set, **set it explicitly.** Defaults differ between models and
    have changed between releases, so an omitted field is a decision made by
    whatever you happen to be pointed at.

11. **Do not fix a leak by telling the model not to think.** It is the
    documented way to make it worse. Two rules, both counter-intuitive:
    delete any "do not reason" instruction, and if you must ask for clean
    output, ask generically ("do not include internal or system tags in your
    response") rather than naming the tags — naming them is measurably weaker.
    The skill carries the current wording and which models need it.

12. **Bound the output, and remember the ceiling covers thinking.** The token
    ceiling is a hard cap on thinking *plus* the visible answer, so a ceiling
    sized for a two-sentence reply truncates the reply the moment the model
    thinks. Size it for both, and re-check it whenever thinking or effort
    changes.

13. **Say the shape you want in the prompt, and say why.** "The reply is read
    aloud" earns more than a list of banned characters: no formatting a voice
    can carry, no length a listener will sit through. A prompt tuned for one
    model is not automatically right for the next one — re-baseline it on a
    model change rather than assuming it carries over.

## The default adapter ships

14. **When the only real adapter needs a key or a second machine, write a
    degenerate one and make it the default.** [go-config.md](go-config.md)
    rule 3 says an empty environment MUST start a working app; a port whose only
    implementation needs an API key breaks that rule in spirit while satisfying
    its letter.

    ```go
    // Package echo answers without a language model. It exists so the whole
    // loop can be exercised with no key, no local model, and no second machine.
    //
    // This is a product mode, not a test double: `-assistant=echo` is how you
    // find out whether everything around the model works when the answer does
    // not matter yet.
    package echo
    ```

    **Say in the package doc that it is a product mode.** It lives in
    `internal/`, not in a `_test.go` file, and config selects it — that is what
    separates it from the fake in
    [go-ports-adapters.md](go-ports-adapters.md), and the next reader will
    otherwise assume it is a stray test helper and delete it.

15. **Boot MUST NOT reach the model** ([go-http-client.md](go-http-client.md)
    *Boot does not wait on a dependency*). No warm-up call, no capability probe.
    Boot MAY refuse to start over a **local** fact the chosen mode needs — a
    missing credential file for the mode the operator asked for — and that
    error names the file to write.

## Testing

16. **Pin the wire contract against `httptest`, never the live API.** The live
    model is slow, non-deterministic, and somebody's bill. One table over the
    statuses and stop reasons the vendor documents proves the translation:

    ```go
    {"a refusal becomes the sentinel", refusalBody, domain.ErrRefused},
    {"200 with no text is an error, not an empty reply", emptyBody, errTransient},
    {"503 fails without a domain sentinel", "", errTransient},
    ```

17. **Assert the request, not just the response.** The request body is the half
    a fake cannot check and the half that silently rots: the model, the thinking
    setting, the effort level, the token ceiling, the headers. That test is what
    tells you a field was dropped in a refactor, and it is the reason a model
    migration is a green-or-red change rather than a hopeful one.
18. **Never assert on model output.** The content is not under test and cannot
    be. Test the translation layer: shape in, shape out, sentinel on refusal.
19. **The feature is finished against the fake**, before the adapter exists —
    the whole payoff of [go-ports-adapters.md](go-ports-adapters.md).

## SDK or standard library

20. **Both are allowed; pick by what you are building, and record the choice.**

    - **Standard library** for a request you can write out in one struct — a
      reply to a conversation is one endpoint and a handful of fields. This is
      the [stack/go.md](../stack/go.md) default, it adds no dependency, and the
      wire-contract test above is what keeps it honest.
    - **The vendor's official SDK** the moment you need streaming, a tool-use
      loop, structured outputs, or a hosted-agent surface. Hand-rolling those is
      a worse use of the same hours, and the SDK is what the `claude-api` skill
      documents.

    The SDK is not on the approved list in [stack/go.md](../stack/go.md), so
    taking it means a written justification in the project README — which is the
    existing mechanism working, not an obstacle. Going the other way, calling
    the API directly departs from the `claude-api` skill's own default, so
    record *that* in the README too. Either way the next reader learns why.

## Anti-patterns

- ❌ The system prompt inside the adapter. The second adapter copies it, and the
  two answers drift apart with nothing to catch it.
- ❌ Model IDs, beta headers, or pricing written into a document instead of read
  from the `claude-api` skill. They go stale between two verifications of this
  file.
- ❌ Reading `content[0]` before checking the stop reason. The refusal path is
  the one you will not reproduce by hand.
- ❌ A port with an options struct (`Reply(ctx, history, opts)`). It has stopped
  being what the consumer needs and started being what the vendor offers.
- ❌ Asserting on what the model said. The test then fails on a model upgrade
  that improved the product.
- ❌ The live API in CI. Slow, flaky, and billed.
- ❌ An app that cannot start without a key. See rule 14 — the degenerate
  adapter is a day-one decision, not a retrofit.
- ❌ "Do not think" in a prompt, to stop reasoning leaking into the answer. It
  is documented to make the leak worse.
