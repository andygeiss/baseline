# Pattern: Go CLI

**Last verified: 2026-08-10**

The mechanics behind [project-types/cli-tool.md](../project-types/cli-tool.md):
process skeleton, flags, streams, exit codes, version reporting, testing.

## The `run()` skeleton

`main` is wiring only; everything testable lives in `run`:

```go
var errUsage = errors.New("usage error")

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	err := run(ctx, os.Args[1:], os.Stdout, os.Stderr)
	switch {
	case err == nil:
	case errors.Is(err, errUsage):
		os.Exit(2) // message already printed where the error was detected
	default:
		fmt.Fprintf(os.Stderr, "mytool: %v\n", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, args []string, stdout, stderr io.Writer) error {
	// parse flags, dispatch, do the work — everything returns errors upward
}
```

- **`os.Exit` appears in `main` only.** Anywhere else it skips deferred cleanup and
  makes the code untestable. All other code returns errors.
- **`signal.NotifyContext`** cancels `ctx` on the first Ctrl-C/SIGTERM so the
  current unit of work can finish or roll back. The registration stays active
  until `stop()` runs, so further Ctrl-Cs are swallowed — in a tool whose
  shutdown can take more than a heartbeat, restore the force-kill escape hatch by
  adding `go func() { <-ctx.Done(); stop() }()` right after creating the context
  (unregistering returns the signal to its default disposition: terminate).
- **Exit codes:** `0` success, `1` failure, `2` usage error (the `flag` package's
  own convention). Scripts branch on these; don't invent more without documenting
  them in `-h`.

## Flags and subcommands

Stdlib `flag` only — one `FlagSet` per subcommand, `ContinueOnError` so parse
failures return instead of exiting from library code:

```go
func runFetch(ctx context.Context, args []string, stdout, stderr io.Writer) error {
	fs := flag.NewFlagSet("fetch", flag.ContinueOnError)
	fs.SetOutput(stderr)
	limit := fs.Int("limit", 10, "maximum items to fetch")
	jsonOut := fs.Bool("json", false, "emit one JSON object per line")
	if err := fs.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return nil // -h: usage already printed, exit 0
		}
		return errUsage // bad flag: message already printed by fs, exit 2
	}
	// ...
}
```

Dispatch is a switch, not a framework:

```go
func run(ctx context.Context, args []string, stdout, stderr io.Writer) error {
	if len(args) == 0 {
		fmt.Fprint(stderr, usage)
		return errUsage
	}
	switch args[0] {
	case "fetch":
		return runFetch(ctx, args[1:], stdout, stderr)
	case "version":
		fmt.Fprintln(stdout, version())
		return nil
	default:
		fmt.Fprintf(stderr, "unknown command %q\n%s", args[0], usage)
		return errUsage
	}
}
```

Single-purpose tools skip dispatch entirely and parse flags directly in `run`.

## Config precedence

Flags win over environment variables win over built-in defaults — expressed by
making the env var the flag's default:

```go
addr := fs.String("addr", envOr("MYTOOL_ADDR", "localhost:8080"), "server address")

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
```

Env vars are namespaced with the tool's name (`MYTOOL_*`) and documented in `-h`
text (`"server address (env MYTOOL_ADDR)"`). No config files until a real project
demonstrates the need; when that day comes, it's one flag pointing at one file.

## Streams

- **stdout is data.** Parseable, stable across releases, pipe-friendly. Nothing
  else goes there — no banners, no progress, no log lines.
- **stderr is everything else:** diagnostics, progress, usage text, errors.
  `mytool | wc -l` and `mytool > out.txt` must never capture noise.
- **Machine consumers get `-json`:** `encoding/json`, one object per line
  (ND-JSON), field names stable. Human output MAY change between releases; `-json`
  output MUST NOT without a major version.
- **No colors, spinners, or ANSI control sequences.** Plain lines survive pipes,
  CI logs, and `2>err.txt`. Progress on long operations is a plain line to stderr.
- **No prompts.** Input comes from flags, args, env, or stdin. Destructive
  operations take an explicit `-force` flag instead of asking "are you sure?".
- Support `-` as a filename meaning stdin/stdout where the tool reads or writes
  files — it makes the tool composable for free.

## Logging

A short-lived tool doesn't log — it prints to stderr, gated by a `-v` flag for
diagnostic detail. Reach for `log/slog` (per
[go-errors-logging.md](go-errors-logging.md), writing to stderr) only when the
tool runs unattended — in cron, CI, or long batch jobs — where structured,
greppable output earns its noise.

## Version

No ldflags ceremony — the toolchain already stamps everything:

```go
func version() string {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return "unknown"
	}
	if v := info.Main.Version; v != "" && v != "(devel)" {
		return v // built via `go install module@vX.Y.Z`
	}
	rev, dirty := "unknown", ""
	for _, s := range info.Settings {
		switch s.Key {
		case "vcs.revision":
			rev = s.Value
		case "vcs.modified":
			if s.Value == "true" {
				dirty = "-dirty"
			}
		}
	}
	return "devel-" + rev[:min(len(rev), 12)] + dirty
}
```

`go install github.com/andygeiss/<tool>@v1.2.3` reports `v1.2.3`; a build from a
checkout reports `devel-<commit>`. Expose it as a `version` subcommand or
`-version` flag — one of the two, matching the tool's shape.

## Long-running work

- Pass `ctx` all the way down; every loop iteration and every I/O call must be
  cancellable. `ctx.Err()` after the loop tells you whether you finished or were
  interrupted — an interrupted run SHOULD exit non-zero.
- Partial work must be safe: either each unit of work is atomic (temp file +
  rename, SQLite transaction) or the tool is idempotent so rerunning repairs the
  interruption.

## Testing

`run` takes its streams and args, so tests need no process machinery:

```go
func TestRun_Fetch(t *testing.T) {
	var stdout, stderr bytes.Buffer
	err := run(t.Context(), []string{"fetch", "-limit", "2"}, &stdout, &stderr)
	if err != nil {
		t.Fatalf("run: %v (stderr: %s)", err, stderr.String())
	}
	// assert on stdout.String()
}
```

Table-test the argument surface: happy path per subcommand, unknown command,
bad flag (expect `errUsage`), and — for `-json` — that output parses back with
`encoding/json`. Strategy and coverage bar per
[go-testing.md](go-testing.md).
