# Pattern: LLM Prompting and the Visible Answer

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-17

The text you send a model, and the text it sends back. The code around the model — the
port, the adapter, the fake, the degenerate default — is
[go-llm-adapter.md](go-llm-adapter.md); this document is what travels over that wire and
what the reader ends up seeing. It is not Go-specific.

**Model IDs, request fields, beta headers, and token limits are not here, and MUST NOT be
copied here.** The `claude-api` skill owns them — load it before writing or changing a
request, every time.

## Writing the prompt

1. **Prompts are code:** version controlled beside the code that sends them, reviewed like
   code, and written to the bar in [STYLE.md](../STYLE.md) — models follow plain, concrete
   instructions better than clever ones.

   - One instruction per sentence, imperative mood: "Return JSON. Use only these
     fields: …"
   - Show one example of the desired output — it beats every adjective, because "concise"
     is vague to a model and an example is exact.
   - State the audience and the bar inside the prompt: "Write so a smart 10-year-old
     could follow it."
   - Order it top-down: context → task → constraints → output format.
   - A one-line role ("You are a Go code reviewer.") is enough. Stacked superlatives and
     magic phrases add tokens, not quality.

2. **The prompt is a product rule, so it lives in `domain`** — one copy, shared by every
   adapter. [go-llm-adapter.md](go-llm-adapter.md) owns that placement and the reason.

## The visible text is the product

This is the trap with no compile error and no failing test — only a reply that reads
wrong.

3. **A reasoning model can write its reasoning into the answer.** The text you render,
   speak, or store is the product; a leaked scratchpad — "Here's my thinking process:
   1. Analyze the user input…" — ships silently. It happens from **both** directions,
   which is why one rule cannot cover it:

   - **A frontier model with thinking switched off** may write longer reasoning into the
     visible response. Leave adaptive thinking **on** and control cost with the effort
     setting instead; on current models a low effort level also costs less than a
     disabled-thinking request that rambles.
   - **A local reasoning model with thinking switched on** writes its scratchpad into the
     reply. Ask its chat template to turn thinking off — a server that does not know the
     field ignores it.

   Whichever you set, **set it explicitly.** Defaults differ between models and have
   changed between releases, so an omitted field is a decision made by whatever you happen
   to be pointed at.

4. **Do not fix a leak by telling the model not to think** — it is the documented way to
   make it worse. Delete any "do not reason" instruction, and if you must ask for clean
   output, ask generically ("do not include internal or system tags in your response")
   rather than naming the tags, which is measurably weaker. The skill carries the current
   wording and which models need it.

5. **Bound the output, and remember the ceiling covers thinking.** The token ceiling caps
   thinking *plus* the visible answer, so a ceiling sized for a two-sentence reply
   truncates the reply the moment the model thinks. Size it for both, and re-check
   whenever thinking or effort changes.

6. **Say the shape you want in the prompt, and say why.** "The reply is read aloud" earns
   more than a list of banned characters. A prompt tuned for one model is not
   automatically right for the next — re-baseline it on a model change.

