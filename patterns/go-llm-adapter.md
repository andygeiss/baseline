# Pattern: LLM Adapter (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-17

A language model is somebody else's system reached over HTTP, so
[go-ports-adapters.md](go-ports-adapters.md) already governs the shape: a small port the
consumer declares, an adapter that translates, a hand-written fake. This document is that
shape when the other side is a model, plus the three traps specific to models — each of
which costs a product bug rather than a compile error. **Assume every service grows one**,
and read this before the first request.

## What this document does not own

**Model IDs, request fields, beta headers, pricing, and token limits are not here, and
MUST NOT be copied here.** They change every few weeks against a ninety-day re-verification,
so a pin written here is a wrong answer with a long shelf life.

> **The `claude-api` skill is the source of truth for anything on the wire.** Load it
> before writing or changing a request, every time — including when you are "just"
> changing a model ID. Your training data is not current.

That skill wins on every fact it covers. This document owns the shape around it.

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

Each adapter imports `internal/domain` and nothing else of yours, and `go list -deps`
proves it ([go-ports-adapters.md](go-ports-adapters.md)).

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

1. **One method, domain types, no vendor words.** No `max_tokens`, no `temperature`, no
   `*http.Response`, no model ID. A port that names the vendor's parameters is the
   vendor's SDK wearing a costume, and swapping the model becomes a change to every
   caller.
2. **Every knob stays inside the adapter** — model, effort, token ceiling, timeouts,
   retries, headers. `main` chooses *which* adapter; the adapter chooses how it talks.
3. **The port's doc comment names every error a caller branches on.** That sentence is
   the contract the fake and the adapter both have to meet.

**A port that streams takes a callback.** An answer read aloud, or typed onto a screen as
it arrives, cannot wait for its last token — so the port hands each piece over as it
comes, and the shape stays one method with no vendor words in it:

```go
// Reply hands each piece of the answer to emit as the model writes it, and
// returns when the answer is complete.
Reply(ctx context.Context, history []domain.Message, emit func(string) error) error
```

The callback is what keeps the error handling in one place: the adapter returns why it
stopped, and an error from `emit` comes back unwrapped so the caller recognises its own.
A channel needs a second channel for the error and a goroutine to feed both; an iterator
puts the failure in a loop variable a caller can forget to read.

## The prompt is a product rule, so it lives in `domain`

```go
// internal/domain/prompt.go

// SystemPrompt is how the assistant speaks. It lives here, next to the types
// both adapters use, because it is a product rule rather than a detail of any
// one vendor's API.
const SystemPrompt = `...`
```

4. **One prompt, in `domain`, shared by every adapter.** Put it in the adapter and the
   second adapter gets a copy, the two drift, and the product answers differently
   depending on a flag nobody connects to the symptom.
5. **The conversation's required shape is domain's too.** Every chat model wants the user
   first, and a transcript reaches a worse shape on its own: a turn that fails after the
   question is stored leaves it unanswered, so the next turn puts two user messages in a
   row. Vendors disagree on what that means — one rejects it, the next merges the turns, a
   local chat template silently builds a malformed prompt — and none of those is the
   conversation you meant to send. Normalise once, in `domain`:

   ```go
   // internal/domain/message.go

   // Alternating returns the history the way a model has to be given it: the
   // user speaks first, and from there the two take strict turns. Two turns by
   // one speaker are one turn to the model, so they are joined, not dropped.
   func Alternating(history []Message) []Message
   ```

   Test it against the failure that produces it — an unanswered question — not only
   against a tidy transcript.

6. **How the prompt is written, and what the model writes back, is its own document.**
   [llm-prompting.md](llm-prompting.md) owns both — the prompt-writing rules, the thinking
   and effort settings, and the reasoning that leaks into the visible answer. Read it
   before writing the prompt; nothing below depends on it.

## The adapter translates, in both directions

7. **A refusal is a sentinel, not an error.** A model declining to answer is a normal
   outcome the caller branches on, so it becomes `domain.ErrRefused` instead of a 500.
   Each vendor signals it differently — the `claude-api` skill names the current field —
   and the adapter is where that vendor word disappears.

8. **Check the refusal before you read the text.** A declined request is a **successful
   HTTP 200** with empty or partial content, so reading the first content block before
   the stop reason panics or returns nonsense on the path hardest to reproduce by hand:

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

   **On a stream the check cannot come first, so decide what a late refusal costs.** The
   stop reason arrives after the text it applies to, and the vendor's advice — discard
   the partial — assumes the partial is still yours to discard. It is not, once it has
   been shown or read out loud. Watch for the refusal beside the text, stop the stream on
   it, and report it without deciding anything about what already went out: the caller is
   the only one that knows whether those words have left the building.

   Where the vendor offers a **server-side fallback** — a declined request answered by
   another model in the same call — prefer it to your own retry: one round trip, no state.
   Take the parameter and its beta header from the skill together; they are a matched pair,
   and mixing one form's header with another's body is a 400.

9. **Everything else is transient.** Wrap it with what you were doing and let the caller
   decide ([go-errors-logging.md](go-errors-logging.md)). Transport, timeouts, body caps,
   and the `drainAndClose`/`statusError` helpers are
   [go-http-client.md](go-http-client.md)'s job and do not change here.

## The default adapter ships

10. **When the only real adapter needs a key or a second machine, write a degenerate one
    and make it the default.** [go-config.md](go-config.md) rule 3 says an empty
    environment MUST start a working app, and a port whose only implementation needs an API
    key breaks that rule in spirit while satisfying its letter.

    ```go
    // Package echo answers without a language model. It exists so the whole
    // loop can be exercised with no key, no local model, and no second machine.
    //
    // This is a product mode, not a test double: `-assistant=echo` is how you
    // find out whether everything around the model works when the answer does
    // not matter yet.
    package echo
    ```

    **Say in the package doc that it is a product mode.** It lives in `internal/` and
    config selects it — that is what separates it from the fake in
    [go-ports-adapters.md](go-ports-adapters.md), and the next reader otherwise deletes it
    as a stray test helper.

11. **Boot MUST NOT reach the model** ([go-http-client.md](go-http-client.md) *Boot does
    not wait on a dependency*). No warm-up call, no capability probe. Boot MAY refuse to
    start over a **local** fact the chosen mode needs — a missing credential file — and
    that error names the file to write.

## Testing

12. **Pin the wire contract against `httptest`, never the live API.** One table over the
    statuses and stop reasons the vendor documents proves the translation:

    ```go
    {"a refusal becomes the sentinel", refusalBody, domain.ErrRefused},
    {"200 with no text is an error, not an empty reply", emptyBody, errTransient},
    {"503 fails without a domain sentinel", "", errTransient},
    ```

13. **Assert the request, not just the response** — the model, the thinking setting, the
    effort level, the token ceiling, the headers. That is the half a fake cannot check and
    the half that silently rots, and pinning it makes a model migration green-or-red
    rather than hopeful.
14. **Never assert on model output.** The content is not under test and cannot be. Test
    the translation layer: shape in, shape out, sentinel on refusal.
15. **The feature is finished against the fake**, before the adapter exists — the whole
    payoff of [go-ports-adapters.md](go-ports-adapters.md).

## SDK or standard library

16. **Both are allowed; pick by what you are building, and record the choice.** Use the
    **standard library** for a request you can write out in one struct — that is the
    [stack/go.md](../stack/go.md) default, it adds no dependency, and the wire-contract
    test keeps it honest. Take **the vendor's official SDK** the moment you need
    streaming, a tool-use loop, structured outputs, or a hosted-agent surface.

    **Count the adapters the SDK would cover before you take it.** The trigger is per
    adapter, not per project. A service with a vendor adapter and a local one —
    `internal/openai` against oMLX, Ollama, or vLLM — writes the second event reader by
    hand either way, so the SDK buys one of two while the dependency lands on the whole
    module. A `data:` line reader over `bufio.Scanner` is about twenty lines, and rule 12
    pins it.

    Either choice is a departure somebody has to justify in the project README: the SDK is
    not on the approved list in [stack/go.md](../stack/go.md), and calling the API directly
    departs from the `claude-api` skill's own default.

## Anti-patterns

- ❌ A port with an options struct (`Reply(ctx, history, opts)`). It has stopped being
  what the consumer needs and started being what the vendor offers.
- ❌ The system prompt inside the adapter — the second adapter copies it, and the two
  drift.
