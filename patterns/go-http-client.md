# Pattern: HTTP Client (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-08-17

Calling someone else's HTTP API. Stdlib only. The rule that matters most is the
first one, because the default is wrong:

> **`http.DefaultClient` has no timeout.** A hung server holds your goroutine,
> its connection, and whatever request context it came from — forever. So does
> `http.Get`, `http.Post`, and every other package-level helper, because they
> all use it.

MUST NOT use `http.DefaultClient` or the package-level helpers in any code that
ships. Build a client, give it a timeout, inject it.

## The client

One client per external dependency, built at startup next to every other
dependency, injected as a struct field:

```go
// internal/weather/client.go

// Client talks to the weather API. It owns its http.Client so callers cannot
// hand it one without timeouts.
type Client struct {
	http    *http.Client
	baseURL string
	key     string
}

func NewClient(baseURL, key string) *Client {
	tr := http.DefaultTransport.(*http.Transport).Clone()
	tr.MaxIdleConnsPerHost = 10 // the default of 2 makes a busy dependency reconnect constantly
	// ResponseHeaderTimeout has no default. Without it, a server that accepts the
	// connection and then never answers is caught only by the client's own Timeout.
	tr.ResponseHeaderTimeout = 5 * time.Second

	return &Client{
		http:    &http.Client{Transport: tr, Timeout: 10 * time.Second},
		baseURL: baseURL,
		key:     key,
	}
}
```

- **`Timeout` covers the whole exchange** — dial, request, response, *and*
  reading the body. It is the backstop; `ResponseHeaderTimeout` is the one that
  tells a slow answer apart from a slow download.
- **`Timeout` bounds one attempt, not one call.** With the retries below, the
  worst case is roughly `maxAttempts × Timeout` plus the backoff. The caller's
  context is what bounds the whole operation, which is why every method takes
  one.
- **Clone `http.DefaultTransport`, never build a bare `&http.Transport{}`** —
  the default carries proxy support, HTTP/2, and sane dial timeouts that an
  empty struct silently drops.
- **One transport, reused.** A transport per request defeats connection
  pooling and leaks file descriptors under load — this is the single most
  expensive mistake in this document. The `Client` struct exists to make
  reuse the only convenient option.
- **The package exposes domain methods, not HTTP.** `Forecast(ctx, city)
  (domain.Forecast, error)` — never a `*http.Response`. The rest of the app
  should not know this dependency speaks HTTP, so swapping it for a fake in
  tests is one small interface, per [go-testing.md](go-testing.md).
- MUST NOT set `InsecureSkipVerify`. A certificate that fails to verify is the
  system working.

## The timeout ladder

The two settings above are the outbound half of four: the server has `WriteTimeout`, and
the handler may own a budget ([go-http-server.md](go-http-server.md)). Setting each
sensibly on its own is not enough — **their order decides which one fires, and only the
innermost one can still produce an answer.**

A handler that calls somebody else's system owns a deadline of its own: one named
constant, one `context.WithTimeout(r.Context(), turnBudget)` at the top, and every call
below it taking that `ctx`. Name it for the unit of work it bounds — the next two rows
are set by reading it.

| Layer | Setting | Where it sits |
|---|---|---|
| Server | `WriteTimeout` | **above** the budget — the handler ends the work, not the socket |
| Handler | `context.WithTimeout` | **the budget**: one owner per request path |
| Outbound client | `http.Client.Timeout` | **at or above** the budget — the budget is what gives up |
| Outbound transport | `ResponseHeaderTimeout` | **below** the client timeout — tells a silent server from a slow download |

Get the order wrong and the failure is silent in both directions. **`WriteTimeout` below
the budget** kills the connection while the handler works on: the client sees a truncated
response, the handler logs a success, and nothing names a timeout. **A client timeout
below the budget** makes "this dependency is slow" and "we gave up on it" the same event,
so the retries spend the budget re-asking a dependency that was about to answer.

**Raising the client timeout to meet the budget retires the retries on that path** — the
trade, not an oversight. `Timeout` bounds one attempt, so once it reaches the budget the
first attempt can use all of it and the context ends the work before a second starts.

**A handler that inherits only `r.Context()` has no deadline of its own** — it runs until
the client disconnects or `WriteTimeout` kills the socket. Fine for a query measured in
milliseconds, wrong for anything that waits on another system.

Widening `WriteTimeout` past its canonical 30 s is a tier-2 waiver — record it, and name
the budget that contains it. "The work takes longer than 30 s" is the reason to add a
budget, not to skip one, and adopting one means setting all three rows in that order.

## One request, end to end

```go
func (c *Client) Forecast(ctx context.Context, city string) (domain.Forecast, error) {
	endpoint := c.baseURL + "/forecast?city=" + url.QueryEscape(city)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return domain.Forecast{}, fmt.Errorf("weather: build request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.key)
	req.Header.Set("Accept", "application/json")

	resp, err := c.do(req)
	if err != nil {
		return domain.Forecast{}, fmt.Errorf("weather: forecast %q: %w", city, err)
	}
	defer drainAndClose(resp.Body)

	if resp.StatusCode != http.StatusOK {
		return domain.Forecast{}, fmt.Errorf("weather: forecast %q: %w", city, statusError(resp))
	}

	var out domain.Forecast
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&out); err != nil {
		return domain.Forecast{}, fmt.Errorf("weather: decode forecast: %w", err)
	}
	return out, nil
}
```

Five things there are not optional:

1. **`http.NewRequestWithContext`,** always. The caller's context is how a
   client disconnect or a shutdown cancels this call. A request built without
   it ignores both.
2. **A non-2xx status is not an error from `Do`.** `Do` returns `err == nil`
   for a 500 — it completed the exchange, which is all it promises. Check
   `resp.StatusCode` yourself, every time. This is the most common outbound
   bug after the missing timeout.
3. **`defer` a close on every response with `err == nil`,** including the
   error paths below it. A leaked body is a leaked connection.
4. **Cap the body you read.** `io.LimitReader` is the outbound twin of
   `http.MaxBytesHandler` ([go-http-server.md](go-http-server.md)): a broken or
   hostile server can stream until you run out of memory. 1 MiB unless the API
   documents a larger legitimate response.
5. **Wrap errors with what you were doing** (`%w`, per
   [go-errors-logging.md](go-errors-logging.md)). "connection refused" alone
   names no dependency and no operation.

The two helpers:

```go
// drainAndClose returns the connection to the idle pool. Closing an unread
// body throws the connection away instead of reusing it — but draining an
// unbounded one is a DoS, so the drain is capped.
func drainAndClose(body io.ReadCloser) {
	_, _ = io.Copy(io.Discard, io.LimitReader(body, 4<<10))
	_ = body.Close()
}

// statusError reports the status and a short prefix of the body — an API's
// error message is the fastest route to the cause, and the cap keeps a
// 10 MB HTML error page out of the logs.
func statusError(resp *http.Response) error {
	snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
	return fmt.Errorf("%s: %s", resp.Status, bytes.TrimSpace(snippet))
}
```

## Retries

Retry only what is safe to repeat, only for failures a repeat can fix, and
never without a bound.

```go
const maxAttempts = 3

// do sends req, retrying transient failures with exponential backoff. It
// retries only what is safe to repeat: an idempotent method with a body it can
// rebuild. Everything else gets exactly one attempt — see the rules below.
func (c *Client) do(req *http.Request) (*http.Response, error) {
	var lastErr error
	base := 100 * time.Millisecond
	delay := jitter(base) // the exact wait before the next attempt

	// Do consumes and closes req.Body, so a second attempt needs GetBody to
	// rebuild it. NewRequestWithContext fills GetBody in for *bytes.Buffer,
	// *bytes.Reader and *strings.Reader — for any other reader it is nil, and
	// replaying without it would send an empty body that the server accepts as
	// a valid, wrong PUT. No replay available means no retry.
	replayable := req.Body == nil || req.GetBody != nil

	for attempt := 1; ; attempt++ {
		resp, err := c.http.Do(req)
		switch {
		case err != nil:
			if req.Context().Err() != nil {
				return nil, err // the context died, not the server
			}
			lastErr = err
		case !retryableStatus(resp.StatusCode):
			return resp, nil // including 4xx: retrying a bad request just repeats it
		default:
			if after, ok := retryAfter(resp); ok {
				delay = after // the server named a wait; it outranks the formula
			}
			lastErr = statusError(resp)
			drainAndClose(resp.Body)
		}

		if !idempotent(req.Method) || !replayable {
			return nil, fmt.Errorf("%s %s: %w", req.Method, req.URL.Host, lastErr)
		}
		if attempt == maxAttempts {
			return nil, fmt.Errorf("gave up after %d attempts: %w", maxAttempts, lastErr)
		}
		if err := sleep(req.Context(), delay); err != nil {
			return nil, err // caller gave up, or shutdown: stop retrying
		}
		base *= 2
		delay = jitter(base)
		if req.GetBody != nil { // the previous attempt consumed the body
			body, err := req.GetBody()
			if err != nil {
				return nil, err
			}
			req.Body = body
		}
	}
}
```

The five helpers are ordinary once their contract is fixed, so this is the contract
rather than another sixty lines:

- `idempotent(method)` — GET, HEAD, PUT, DELETE, **enforced here rather than left to the
  caller's memory**. POST is absent: a retried POST can charge a card twice, and no
  status code tells you whether it did. If a POST genuinely must be retried the API needs
  an idempotency key — the API's design problem, and this function is where you would
  then make the exception, deliberately and in one place.
- `retryableStatus(code)` — 429, 502, 503, 504. **500 is absent on purpose:** it usually
  means a bug on the other side, and retrying a bug multiplies the load at the worst
  moment.
- `jitter(d)` — a random duration in `[d/2, d)`, from `math/rand/v2`
  ([stack/go.md](../stack/go.md)): no seeding, and jitter needs no cryptographic
  randomness. A fleet that failed at the same moment must not retry at the same moment;
  keeping half the window fixed leaves the backoff a floor.
- `retryAfter(resp)` — the `Retry-After` header, delay-seconds form only. Reject zero
  along with the negatives ("retry immediately" is what the backoff prevents) and
  anything over 30 s, so a server cannot park a goroutine for an hour. Used as given,
  **never jittered** — the server asked for a specific delay.
- `sleep(ctx, d)` — a `time.Timer` raced against `ctx.Done()`, so a shutdown mid-backoff
  returns instead of waiting.

Three more rules, which no helper can enforce for you:

- **A body that cannot be replayed cannot be retried.** An idempotent PUT built
  from a plain `io.Reader` (an open file, a pipe) has no `GetBody`, and the
  first attempt drains it. Retrying then sends *nothing* — and unlike a network
  error, the server answers 200 to the empty body it was given. Buffer the body
  first if the retry matters more than the memory.
- **The context outranks the retry budget.** Three attempts inside a 10-second
  context is three attempts *or* 10 seconds, whichever comes first.
- **Retries hide outages.** Log at the point of final failure, not per attempt,
  or one flapping dependency floods the logs.

## Boot does not wait on a dependency

**Nothing that a remote system has to answer may run at startup.** No health
probe, no capability lookup, no connection warm-up. Boot validates what is
local — flags, files, the database this binary owns
([go-config.md](go-config.md)) — and stops there.

A call at boot inverts who is allowed to be down: *their* outage becomes *your* process
failing to start, and under a supervisor that restarts on failure it becomes a crash loop
that outlives the outage. A running app with one broken feature is strictly better — the
rest works, `/healthz` still answers, and the failure is a log line instead of an incident.

So fetch on first use, and keep the answer. Three fields on the adapter's `Client` — the
configured value, a `sync.Mutex`, and the resolved one — and a method that returns the
configured value if there is one, otherwise takes the lock, returns the resolved value if
the first caller already got it, and otherwise asks the server and stores the answer. A
failed lookup returns the error and stores nothing, so **this request fails and the next
one tries again**.

The mutex is the whole concurrency story: requests overlap, and the lookup should happen
once. `sync.OnceValue` is the shorter form when the value needs no context and cannot fail
— but it caches a *failure* forever if you bend it into one, which is why a fallible lookup
uses the mutex and leaves the next request free to retry.

Boot MAY refuse to start over a **local** fact the binary cannot work without: a missing
credential file for the mode the operator asked for, an unreadable database path, a file
named by a flag that is not there. One line, name the fix, exit 2
([go-config.md](go-config.md)).

## Testing

`httptest.Server` gives you the real client against a real socket — no mocking framework,
per [go-testing.md](go-testing.md). Point `NewClient` at `srv.URL`, and let the handler
decide what to fail on.

- **Count calls with `atomic.Int64`, never a plain `int`.** The handler runs on the
  server's goroutine and the assertions run on the test's, and CI runs `-race`.
- Test the failure paths production will actually hit: a non-2xx status, a body that is
  not the JSON you expected, and a context canceled mid-flight.
- Timeout behavior belongs in `testing/synctest` rather than a real one-second wait.

## Libraries do not build clients

A library MUST accept the client instead of constructing one — either `*http.Client` or a
one-method interface it defines ([library.md](../project-types/library.md)). A library that
builds its own has chosen a timeout and retry policy for every consumer with no way to
reverse it. Watch the nil case: treating a nil client as `http.DefaultClient` is exactly how
the missing timeout comes back. Either document nil as a programmer error, or substitute a
client that has one.

## Anti-patterns

- ❌ resty, retryablehttp, gorequest, a circuit-breaker package. The whole
  pattern above is stdlib and fits on two screens; none of these are on the
  approved list in [stack/go.md](../stack/go.md).
