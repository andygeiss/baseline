# Pattern: Sending Mail (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-17

Building the link from `Config` rather than from the request, and refusing a carriage
return or newline in any header value, are tier 1. The port, the outbox, and which
transport a project picks are tier 2.

[go-auth-sessions.md](go-auth-sessions.md) says the plaintext reset token "goes in the
emailed link once" and stops there. This document is the rest of that sentence. Mail is an
outbound dependency like any other: a port declared by whatever calls it, an adapter in
its own package, and a hand-written fake beside the consumer's tests
([go-ports-adapters.md](go-ports-adapters.md) rules 1 and 6) — nothing here changes that
shape. **The consumer is usually not a handler**, because a handler queues rather than
sends, so the port normally lives with the background sender. What is special about mail
is that the message carries a credential to an address somebody typed.

## The link comes from Config, never from the request

**Tier 1, and the whole reason this document exists.**

```go
// Never this, however convenient it reads:
//
//	link := fmt.Sprintf("https://%s/reset?t=%s", r.Host, token)
//
// r.Host is whatever the client put in the Host header, so that line mails a
// working token to the attacker's own server the moment they ask for a reset
// with Host: evil.example.
//
// cfg.BaseURL is a *url.URL parsed and validated at boot (go-config.md): one
// value, the same in every message, checked once. JoinPath returns a copy, so
// setting the query here cannot leak into the next message.
u := cfg.BaseURL.JoinPath("reset")
u.RawQuery = url.Values{"t": {token}}.Encode()
link := u.String()
```

A proxy in front of the app does not fix this: `X-Forwarded-Host` is the same header from
one hop further away. Nothing that reaches a handler decides where a link points.

## Every header value is checked for CR and LF

**Tier 1.** A newline inside a subject or an address lets the sender write their own
headers — a `Bcc`, a second `To` — into a message the app signed with its own domain.

The check belongs on the message, in `domain`, so it is true whoever renders it:

```go
// Validate refuses a message before anything writes a header. Every value that
// reaches one is checked, not only the ones that look like user input: To comes
// from a profile page, and a subject is built with somebody's room name in it
// often enough that "this one is ours" is a claim that goes stale.
func (m Mail) Validate() error {
	if m.To == "" {
		return ErrEmailEmpty
	}
	for _, v := range []string{m.To, m.Subject} {
		if strings.ContainsAny(v, "\r\n") {
			return ErrBadHeader
		}
	}
	return nil
}
```

The sender's own address is not on that list because it is not part of a message: it is
one configured value, and the boot check refuses a line break in it once
([go-config.md](go-config.md)). The adapter then renders with nothing left to escape:

```go
// Nothing here escapes a header value, because nothing here may need to — the
// two checks above have already run. That order is the rule: they run before
// anything writes a header, never after.
func (s *Sender) message(m domain.Mail) []byte {
	var b bytes.Buffer
	fmt.Fprintf(&b, "From: %s\r\n", s.from)
	fmt.Fprintf(&b, "To: %s\r\n", m.To)
	// QEncoding leaves plain ASCII alone and encodes anything else, so a room
	// name with an umlaut in the subject arrives as one.
	fmt.Fprintf(&b, "Subject: %s\r\n", mime.QEncoding.Encode("utf-8", m.Subject))
	b.WriteString("MIME-Version: 1.0\r\n")
	b.WriteString("Content-Type: text/plain; charset=utf-8\r\n\r\n")
	b.WriteString(m.Text)
	return b.Bytes()
}
```

The body needs no escaping of its own: `net/smtp` writes it through a `textproto`
dot-writer, which handles a line that is a single dot and the CRLF endings. Do not
hand-roll either.

## The message is queued, not sent, inside the handler

An outbox table, written in the same transaction as the thing that caused the mail:

- **One transaction.** The reset token row and its outbox row commit together, or neither
  does. A token nobody was told about is a dead end; a mail promising a token that was
  never stored is worse.
- **A ticker sends** — under the errgroup, run before its first tick
  ([go-background-work.md](go-background-work.md)). It reads unsent rows, sends each,
  marks it sent, and gives up on a row after a bounded number of attempts.
- **The handler answers immediately.** SMTP takes seconds and can hang; a handler waiting
  on it holds a request open against `WriteTimeout` and hands the reader a 500 for
  somebody else's outage.
- **A send failure is a `Warn` line and an unsent row**, never a change in what the user
  saw. Whether an address exists MUST NOT be observable in the response — the
  no-enumeration rule in [go-auth-sessions.md](go-auth-sessions.md) is the reason the
  answer cannot depend on the send.
- **Log the outbox id, never the address or the body.** The body holds the token, and an
  address in a log line is a copy of somebody's data that no account deletion reaches. The
  id resolves to the row for as long as the row exists — and the row goes when the account
  does ([go-data-deletion.md](go-data-deletion.md)).

## Which transport

Pick one, name it in the README, and keep the choice inside the adapter.

- **A relay over `net/smtp`.** Stdlib, no dependency, and enough for a mail service that
  gives you a host, a user, and a password. Two facts about the package: it is **frozen**,
  so it will not grow features, and `smtp.PlainAuth` refuses to send credentials over an
  unencrypted connection unless the host is localhost — a plain-text relay fails at
  authentication rather than leaking the password.
- **A provider's HTTP API.** An ordinary outbound call, so
  [go-http-client.md](go-http-client.md) rules it: injected client, timeout, status
  checked, body capped.
- **The log, in development.** The adapter that needs nothing, so the whole flow runs with
  an empty environment — the same move as the degenerate adapter in
  [go-llm-adapter.md](go-llm-adapter.md). Its delivery target *is* the log, which makes it
  the one place the body is written out and the reason config MUST refuse it in
  production. A developer with no relay can still click the link.

Delivery — SPF, DKIM, DMARC, the sending domain, and who owns the relay — belongs to the
deployment, not to the binary. The operations repository has it. A message this app sends
is correct and still lands in spam if that half is missing.

## Testing

- **A fake mailer beside the consumer's tests** collects messages. Assert the outcome: a
  message to this address whose body holds a link under the configured base URL. Never
  assert call counts ([go-ports-adapters.md](go-ports-adapters.md) rule 6).
- **The `Host` test is the regression test for the tier-1 rule.** Post a password-reset
  request carrying `Host: evil.example` and assert the queued link still points at
  `cfg.BaseURL`.
- **The header test.** A recipient or subject holding `\r\nBcc:` answers
  `domain.ErrBadHeader` and queues nothing.
- **The transport is pinned like any other adapter** — `httptest` for an API, and for
  SMTP a test over the rendered bytes: the headers are there, one blank line ends them,
  and the link is below it rather than in them. Never a live relay.

## Anti-patterns

- ❌ A mail library (gomail, a provider SDK). The port is one method, the message is
  three fields, and the adapter is a dial, a render and a write. None of that earns a
  dependency.
- ❌ Sending inside the handler, or from a bare `go func()`.
- ❌ HTML-only mail. Plain text is the default because it is one body to write, escape and
  test. A project that wants HTML sends both parts and says so in its README.
- ❌ Putting anything but the token in the link. No email address, no user id, no
  `?next=` the recipient can be talked into editing.
- ❌ Reusing the outbox as a job queue. It sends mail. A second kind of work is a second
  table, or it is not a queue problem at all.
