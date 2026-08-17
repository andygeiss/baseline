# Pattern: Configuration (Go)

**Last verified: 2026-08-17**

Every knob the binary has, in one struct, parsed once at startup, validated
before anything opens a socket or a file. This document owns the precedence
rule that [project-types/cli-tool.md](../project-types/cli-tool.md) and
[go-project-layout.md](go-project-layout.md) rule 6 mandate, and produces the
environment contract that [operations/web-application.md](../operations/web-application.md)
publishes.

**Flags beat environment variables beat built-in defaults.** One mechanism
expresses all three: the environment variable is the flag's default value.

## The struct and the parser

Both live in the `main` package (`cmd/server/config.go`, or next to `main.go`
in a CLI module) — configuration is a wiring concern, and `internal/` code must
not read the environment at all:

```go
// Config is every knob this binary has. After parseConfig returns, nothing
// else reads os.Getenv — the struct is the whole contract.
type Config struct {
	Host        string
	Port        string // string: net.JoinHostPort takes one
	DatabaseURL string
	LogLevel    slog.Level
	Env         string // dev | prod — picks text vs JSON log output
	SMTPKey     string // secret: arrives as a file, never a flag or an env var
}

// errUsage is go-cli.md's sentinel: the message was already printed where the
// problem was found, so main only has to pick the exit code. Declare it once
// per main package — a tool that also follows go-cli.md already has it.
var errUsage = errors.New("usage error")

func parseConfig(args []string, stderr io.Writer) (Config, error) {
	fs := flag.NewFlagSet("server", flag.ContinueOnError)
	fs.SetOutput(stderr)

	var c Config
	fs.StringVar(&c.Host, "host", cmp.Or(os.Getenv("HOST"), "127.0.0.1"), "bind address (env HOST)")
	fs.StringVar(&c.Port, "port", cmp.Or(os.Getenv("PORT"), "8080"), "listener port (env PORT)")
	fs.StringVar(&c.DatabaseURL, "database-url", cmp.Or(os.Getenv("DATABASE_URL"), "app.db"), "SQLite file path (env DATABASE_URL)")
	level := fs.String("log-level", cmp.Or(os.Getenv("LOG_LEVEL"), "info"), "debug|info|warn|error (env LOG_LEVEL)")

	// Rule 5: the variables that are not flags have nowhere else to be
	// documented, so -h names them too. Without this, -h is a partial contract.
	fs.Usage = func() {
		fmt.Fprintf(stderr, "Usage of server:\n")
		fs.PrintDefaults()
		fmt.Fprintf(stderr, "\nRead from the environment only:\n"+
			"  ENV\n\tdev|prod, picks text vs JSON logs (default dev)\n"+
			"  CREDENTIALS_DIRECTORY\n\tdirectory holding secret files; set by the deployment\n")
	}

	if err := fs.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return Config{}, err // -h: usage printed, exit 0
		}
		return Config{}, errUsage // fs already printed the message and the usage
	}

	c.Env = cmp.Or(os.Getenv("ENV"), "dev") // not a flag: the deployment sets it, never a command line

	// Cheap checks first — a typo in a flag should not wait on a file read.
	if err := c.LogLevel.UnmarshalText([]byte(*level)); err != nil {
		return Config{}, fmt.Errorf("log-level %q: want debug, info, warn, or error", *level)
	}
	if _, err := strconv.ParseUint(c.Port, 10, 16); err != nil {
		return Config{}, fmt.Errorf("port %q: want a number from 0 to 65535", c.Port)
	}
	if c.Env != "dev" && c.Env != "prod" {
		return Config{}, fmt.Errorf("ENV %q: want dev or prod", c.Env)
	}

	key, err := readCredential("smtp-key")
	if err != nil {
		return Config{}, err
	}
	c.SMTPKey = key
	return c, nil
}
```

`cmp.Or` returns its first non-zero argument, which is the precedence rule
itself in one stdlib call — no helper to write, and empty counts as unset
(`PORT= ./server` is a mistake, not a request for `""`).

`main` maps the three outcomes to exit codes, using
[go-cli.md](go-cli.md)'s codes — `0` success, `2` usage error — with one
deliberate difference from the switch there:

```go
cfg, err := parseConfig(os.Args[1:], os.Stderr)
switch {
case err == nil:
case errors.Is(err, flag.ErrHelp):
	return // -h: usage already printed, exit 0
case errors.Is(err, errUsage):
	os.Exit(2) // the FlagSet already said what was wrong
default:
	fmt.Fprintf(os.Stderr, "server: %v\n", err) // a validation failure, said once
	os.Exit(2) // 2, not go-cli.md's 1 — see below
}
```

**The `default` branch exits 2 here, where [go-cli.md](go-cli.md)'s exits 1.**
That is not a drift: this switch only ever sees errors from `parseConfig`, and
every one of them — a bad port, an unknown log level, an `ENV` that is neither
`dev` nor `prod` — means the operator configured the binary wrong. That is the
definition of exit 2. `go-cli.md`'s `default` covers the work itself failing
after the arguments parsed fine, which is exit 1. A `run()` that does both keeps
the two branches separate rather than collapsing them.

Printing happens in exactly one place per failure kind. A parser that returns
the `flag` package's own error *and* a `main` that prints it produces the
message twice — once from the `FlagSet`, once from `main`.

## Rules

1. **Parse before you build anything.** Configuration errors surface as a
   one-line message and exit 2, before the database opens and before the
   listener binds. A bad `PORT` MUST NOT be discovered by a half-started
   process that already created files. This covers **local** facts only — flags,
   files, the database this binary owns. Nothing another system has to answer
   runs at boot ([go-http-client.md](go-http-client.md) *Boot does not wait on a
   dependency*): validating hard at startup and refusing to start over somebody
   else's outage are different decisions, and only the first one is this rule.
2. **Validate at the edge, store the parsed type.** `LogLevel` is a
   `slog.Level`, not a string that some later code re-parses and re-fails on.
   Parse once, at the boundary; after that the type carries the guarantee.
3. **Every value has a default that works.** `go run ./cmd/server` with an
   empty environment MUST start a working app on `127.0.0.1:8080`. A binary
   that needs six variables before it does anything is a binary nobody can try.
4. **`internal/` never reads the environment.** Pass the fields a package
   needs, not the struct: `app.New(templates, store, cfg.Env == "dev")`. The
   dependency direction forces it — `internal/app` cannot import the `main`
   package's `Config` — and that is the rule working, not an obstacle.
5. **Flag name and env var say the same thing.** `-log-level` ↔ `LOG_LEVEL`.
   The help text names the variable (`"(env LOG_LEVEL)"`), so `-h` is the
   complete contract and no separate document can drift from it. The variables
   that are *not* flags (`ENV`, `CREDENTIALS_DIRECTORY`) have nowhere to say
   that, so set `fs.Usage` to print them under the flag list — otherwise `-h`
   quietly stops being complete.
6. **A CLI namespaces its variables** with the tool's name (`MYTOOL_ADDR`) —
   it shares the environment with everything else on the box. A server does not
   need the prefix: it is deployed alone, and its deployment sets every variable
   it reads.
7. **Settings that only make sense together are validated together.** Rule 2
   checks one field at a time and cannot see a pair, so two flags that are
   really one setting — a reference file and the text describing it, a host and
   the credential for it — get their own check, and it says which half is
   missing and what to do about it:

   ```go
   // beside is the transcript file the recording would carry if it had one:
   // voices/jarvis.opus → voices/jarvis.txt. Naming it in the error is what
   // turns "something is missing" into an instruction.
   beside := strings.TrimSuffix(c.RefAudio, filepath.Ext(c.RefAudio)) + ".txt"

   switch {
   case c.RefAudio != "" && c.RefText == "":
   	return Config{}, fmt.Errorf("tts-ref-audio %q: no transcript — set -tts-ref-text, or write what the recording says into %q", c.RefAudio, beside)
   case c.RefAudio == "" && c.RefText != "":
   	return Config{}, errors.New("tts-ref-text: no -tts-ref-audio — the words describe a recording that was not given")
   }
   ```

   Without it the half-configured pair starts fine and fails on the first
   request that needs it, which is the worst place to find out.

   **A value too long for an environment variable is read from a file**, named
   after the artefact it belongs to (`voices/jarvis.opus` → `voices/jarvis.txt`).
   Pointing at the one file is then the whole setting, and the flag still
   overrides the file. A paragraph in an environment variable is a paragraph
   nobody can read back: every tool that prints a process's environment prints it
   as one unbroken line, and the newlines that made it readable are gone.

## Secrets

**Secrets arrive as files, not as flags and not as environment variables.**
Both of the easy options leak: a flag value shows up in `ps`, in shell history,
and in any process listing, and an environment variable is inherited by every
child process and printed by whatever inspects the running service. A file is
neither. The deployment puts one file per secret in a directory and names that
directory in `$CREDENTIALS_DIRECTORY`; the contract is in
[operations/web-application.md](../operations/web-application.md), and the
operations repository decides what the path actually is.

```go
// readCredential returns the credential file of that name, or "" when the
// deployment passes none — which is the normal case in dev. The caller decides
// whether an empty secret is fatal; that depends on the feature, not on config.
func readCredential(name string) (string, error) {
	dir := os.Getenv("CREDENTIALS_DIRECTORY")
	if dir == "" {
		return "", nil
	}
	b, err := os.ReadFile(filepath.Join(dir, name))
	if err != nil {
		return "", fmt.Errorf("credential %q: %w", name, err)
	}
	return strings.TrimSpace(string(b)), nil // the file usually ends in a newline
}
```

`$CREDENTIALS_DIRECTORY` is set by the deployment, points somewhere only the
service user can read, and is unset in a plain `go run`. That is the one
environment variable the config layer reads for a secret, and it holds a
directory path, not the secret itself. The name is deliberately not tied to any
one runtime: the code says "wherever this deployment keeps its secret files", so
moving the app somewhere else changes the deployment and no Go.

**Keep secrets out of the logs.** Logging the whole config at boot is useful
right up until it prints a key. One method fixes it for good:

```go
// LogValue is what slog logs for a Config: everything except the secrets.
// Adding a secret field to the struct does not add it here.
func (c Config) LogValue() slog.Value {
	return slog.GroupValue(
		slog.String("host", c.Host),
		slog.String("port", c.Port),
		slog.String("database_url", c.DatabaseURL),
		slog.String("env", c.Env),
		slog.String("log_level", c.LogLevel.String()),
	)
}
```

`slog.Any("config", cfg)` now prints the safe fields only. The allowlist is the
point: a redaction blocklist forgets the field somebody adds next year.

### A CLI holds its secret differently

Everything above assumes a deployment — something that starts the process and
can put a file where only that process may read it. A command-line tool has no
such thing. It runs as a person, from a shell, on a laptop, and
[go-cli.md](go-cli.md) sends its configuration through `MYTOOL_*` environment
variables. Read the two rules together and they collide: secrets never come from
the environment, and a CLI's settings always do.

**The file wins, and the environment variable stays available.** A CLI takes its
secret from a file named by `-token-file`, defaulting to `$MYTOOL_TOKEN_FILE`, and
falls back to `$MYTOOL_TOKEN` when neither is set. Document the fallback as what it
is: convenient, and readable by every child process the shell starts. The
ban above is not softened for services — it is scoped to them, because the
mechanism it names (`$CREDENTIALS_DIRECTORY`) only exists where a deployment
does.

## Testing

`parseConfig` takes its arguments and writes to an injected `stderr`, so it
tests without a process:

```go
func TestParseConfig(t *testing.T) {
	t.Setenv("PORT", "9000") // t.Setenv restores it and forbids t.Parallel

	got, err := parseConfig([]string{"-host", "0.0.0.0"}, io.Discard)
	if err != nil {
		t.Fatalf("parseConfig: %v", err)
	}
	if got.Host != "0.0.0.0" {
		t.Errorf("Host = %q, want 0.0.0.0", got.Host)
	}
	if got.Port != "9000" {
		t.Errorf("Port = %q, want 9000 (from the environment)", got.Port)
	}
}
```

Table-test the parts that can actually break: **precedence** (a flag overrides
its environment variable), each **validation failure** (bad port, bad log level,
bad `ENV`), **each half of a paired setting** from rule 7, and the **empty
environment** case from rule 3. Precedence is the
one most likely to regress silently, because a wrong answer still starts.

One more test earns its place the moment the struct holds a secret: set one,
render the config through a `slog` handler, and assert the value does not appear
in the output. That is the test that catches the field somebody adds to `Config`
and forgets to leave out of `LogValue`.

## Anti-patterns

- ❌ viper, koanf, envconfig, godotenv. Twenty lines of stdlib, and none of
  them are on the approved list in [stack/go.md](../stack/go.md).
- ❌ A config file. Flags and environment cover both ways a binary gets
  configured; a file adds a format, a path, a reload question, and a second
  place for the answer to live. When a project genuinely needs one, it is one
  flag pointing at one file — and the flag still wins over the file.
- ❌ `os.Getenv` scattered through `internal/`. The value's origin becomes
  untraceable, tests need the real environment, and nothing can list what the
  binary actually reads.
- ❌ A package-level `var cfg Config`. Global mutable state, initialized by
  `init()` in the worst version, untestable in every version.
- ❌ `log.Fatal` inside the parser. It skips deferred cleanup and cannot be
  tested; return the error and let `main` own the exit code.
- ❌ Defaulting a secret (`cmp.Or(os.Getenv("SMTP_KEY"), "dev-secret")`). The default ships
  to production the day somebody forgets to configure the real one. Leave it
  empty and fail loudly at the point of use.
- ❌ A secret in an environment variable or a committed `.env` file. The first
  is readable by anything that can inspect the process and the second lives in
  the repository forever; use the credential file above. An **uncommitted**
  `.env` that `make run` sources
  ([stack/makefile.md](../stack/makefile.md) rule 6) is a different thing: a
  developer's own machine, gitignored, and never how a deployment gets a
  secret. The word doing the work in this bullet is *committed*.
