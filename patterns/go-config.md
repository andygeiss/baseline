# Pattern: Configuration (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-09-08

**The rules in *Secrets* are tier 1 and never waived:** a secret arrives as a file, never
as a flag value or an environment variable, and its own type keeps it out of the logs.
Either one leaks an account if dropped, which is the README's own test for tier 1.
**So are the two boot checks [go-email.md](go-email.md) rests its tier-1 rules on:**
`BaseURL`, and a sender address refused when it holds CR or LF.

Every knob the binary has, in one struct, parsed once at startup, validated before
anything opens a socket or a file. This document owns the precedence rule that
[project-types/cli-tool.md](../project-types/cli-tool.md) and
[go-project-layout.md](go-project-layout.md) rule 6 mandate, and produces the environment
contract that [operations/web-application.md](../operations/web-application.md) publishes.

**Flags beat environment variables beat built-in defaults.** One mechanism expresses all
three: the environment variable is the flag's default value.

## The struct and the parser

Both live in the `main` package (`cmd/server/config.go`, or next to `main.go` in a CLI
module) — configuration is wiring, and `internal/` code must not read the environment:

```go
// Config is every knob this binary has. After parseConfig returns, nothing
// else reads os.Getenv — the struct is the whole contract.
type Config struct {
	Host        string
	Port        string   // string: net.JoinHostPort takes one
	BaseURL     *url.URL // public origin; every emailed link is built from it
	DatabaseURL string
	LogLevel    slog.Level
	Env         string // dev | prod — picks text vs JSON log output
	MailFrom    string // sender address; refused at boot if it holds CR or LF
	SMTPKey     Secret // secret: arrives as a file, never a flag or an env var
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
	fs.StringVar(&c.MailFrom, "mail-from", cmp.Or(os.Getenv("MAIL_FROM"), "no-reply@localhost"), "sender address (env MAIL_FROM)")
	level := fs.String("log-level", cmp.Or(os.Getenv("LOG_LEVEL"), "info"), "debug|info|warn|error (env LOG_LEVEL)")
	// No cmp.Or default: -host and -port are not parsed yet.
	base := fs.String("base-url", os.Getenv("BASE_URL"), "public origin for emailed links (env BASE_URL)")

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
	// url.Parse errors on almost nothing: "evil.example", "/reset" and
	// "javascript:alert(1)" all parse. The scheme and the host are the check.
	u, err := url.Parse(cmp.Or(*base, "http://"+net.JoinHostPort(c.Host, c.Port)))
	if err != nil || u.Host == "" || (u.Scheme != "http" && u.Scheme != "https") {
		return Config{}, fmt.Errorf("base-url %q: want an absolute http or https URL", *base)
	}
	c.BaseURL = u
	if strings.ContainsAny(c.MailFrom, "\r\n") {
		return Config{}, fmt.Errorf("mail-from %q: holds a carriage return or newline", c.MailFrom)
	}

	key, err := readCredential("smtp-key")
	if err != nil {
		return Config{}, err
	}
	c.SMTPKey = Secret(key)
	return c, nil
}
```

`cmp.Or` returns its first non-zero argument, which is the precedence rule in one stdlib
call — and empty counts as unset (`PORT= ./server` is a mistake, not a request for `""`).

`main` switches on the error from `parseConfig` and maps three outcomes to
[go-cli.md](go-cli.md)'s exit codes: `flag.ErrHelp` returns with exit 0 (usage already
printed), `errUsage` exits 2 printing nothing (the `FlagSet` already said what was wrong),
and anything else prints `server: <err>` once and exits 2.

**That last branch exits 2 where [go-cli.md](go-cli.md)'s exits 1**, and that is not
drift: every error `parseConfig` returns means the operator configured the binary wrong,
which is what exit 2 is for, while `go-cli.md`'s `default` covers the work itself failing
after the arguments parsed. Printing happens in exactly one place per failure kind.

## Rules

1. **Parse before you build anything.** Configuration errors surface as a one-line
   message and exit 2, before the database opens and before the listener binds. A bad
   `PORT` MUST NOT be discovered by a half-started process that already created files.
   This covers **local** facts only — flags, files, the database this binary owns. Nothing
   another system has to answer runs at boot ([go-http-client.md](go-http-client.md)
   *Boot does not wait on a dependency*): validating hard at startup and refusing to
   start over somebody else's outage are different decisions, and only the first is this
   rule.
2. **Validate at the edge, store the parsed type.** `LogLevel` is a `slog.Level`, not a
   string that some later code re-parses and re-fails on.
3. **Every value has a default that works.** `go run ./cmd/server` with an empty
   environment MUST start a working app on `127.0.0.1:8080`. A binary that needs six
   variables before it does anything is a binary nobody can try.
4. **`internal/` never reads the environment.** Pass the fields a package needs, not the
   struct: `app.New(templates, store, cfg.Env == "dev")`. The dependency direction forces
   it — `internal/app` cannot import the `main` package's `Config` — and that is the rule
   working, not an obstacle.
5. **Flag name and env var say the same thing.** `-log-level` ↔ `LOG_LEVEL`. The help
   text names the variable (`"(env LOG_LEVEL)"`), so `-h` is the complete contract and no
   separate document can drift from it. The variables that are *not* flags (`ENV`,
   `CREDENTIALS_DIRECTORY`) have nowhere to say that, so `fs.Usage` prints them under the
   flag list — otherwise `-h` quietly stops being complete.
6. **A CLI namespaces its variables** with the tool's name (`MYTOOL_ADDR`) — it shares
   the environment with everything else on the box. A server does not need the prefix: it
   is deployed alone.
7. **Settings that only make sense together are validated together.** Rule 2 checks one
   field at a time and cannot see a pair, so two flags that are really one setting — a
   reference file and the text describing it, a host and the credential for it — get
   their own check, naming which half is missing and what to do:

   ```go
   switch {
   case c.RefAudio != "" && c.RefText == "":
   	// Naming the file the transcript belongs in turns "something is
   	// missing" into an instruction.
   	beside := strings.TrimSuffix(c.RefAudio, filepath.Ext(c.RefAudio)) + ".txt"
   	return Config{}, fmt.Errorf("tts-ref-audio %q: no transcript — set -tts-ref-text, or write what the recording says into %q", c.RefAudio, beside)
   case c.RefAudio == "" && c.RefText != "":
   	return Config{}, errors.New("tts-ref-text: no -tts-ref-audio — the words describe a recording that was not given")
   }
   ```

   Without it the half-configured pair starts fine and fails on the first request that
   needs it, which is the worst place to find out.

   **A value too long for an environment variable is read from a file**, named after the
   artefact it belongs to (`voices/jarvis.opus` → `voices/jarvis.txt`). Pointing at the
   one file is then the whole setting, and the flag still overrides it. A paragraph in an
   environment variable is a paragraph nobody can read back: every tool that prints a
   process's environment prints it as one unbroken line.

8. **A value the app cannot work out at request time is a flag with an environment
   default, validated at boot.** `BASE_URL` is the one this baseline names: no request
   carries a trustworthy answer for where the app lives, so
   [go-email.md](go-email.md)'s tier-1 rule has nothing to build a link from without it.
   The fallback is the listener's own address, so a deployment behind anything MUST set it.

## Secrets

**Secrets arrive as files, not as flags and not as environment variables.** Both easy
options leak: a flag value shows up in `ps`, in shell history, and in any process
listing; an environment variable is inherited by every child process and printed by
whatever inspects the running service. A file is neither. The deployment puts one file
per secret in a directory and names that directory in `$CREDENTIALS_DIRECTORY` — the
contract is in [operations/web-application.md](../operations/web-application.md).

`readCredential(name)` is the whole mechanism: an unset `$CREDENTIALS_DIRECTORY` returns
`"", nil` — the normal case in dev, and **the caller decides whether an empty secret is
fatal**, because that depends on the feature rather than on config. Otherwise it reads the
named file in that directory and `strings.TrimSpace`s the result, since the file usually
ends in a newline.

`$CREDENTIALS_DIRECTORY` holds a directory path rather than a secret, points somewhere only
the service user can read, and is unset in a plain `go run`. Its name is tied to no runtime,
so moving the app elsewhere changes the deployment and no Go.

**Keep secrets out of the logs.** Logging the whole config at boot is useful right up
until it prints a key:

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

`slog.Any("config", cfg)` now prints the safe fields only. The allowlist is the point: a
redaction blocklist forgets the field somebody adds next year.

**`LogValue` alone protects one shape, so a secret is also its own type.** It fires only
when the `Config` *is* the value logged: nested in a struct, in a slice, in a map, or under
any `fmt` verb, slog and fmt print the fields themselves. The type holds in all four:

```go
// Secret is a value that must never reach a log line. The three methods are the
// three ways a value gets printed: slog, fmt, and anything writing text.
type Secret string

func (Secret) LogValue() slog.Value         { return slog.StringValue("REDACTED") }
func (Secret) String() string               { return "REDACTED" }
func (Secret) MarshalText() ([]byte, error) { return []byte("REDACTED"), nil }
```

Neither method survives `%#v` or an explicit `string(s)`, and nothing in the type system can.

### A CLI holds its secret differently

Everything above assumes a deployment — something that can put a file where only that
process may read it. A command-line tool has none: it runs as a person, from a shell, and
[go-cli.md](go-cli.md) sends its configuration through `MYTOOL_*` environment variables.
Read the two rules together and they collide.

**The file wins, and the environment variable stays available.** A CLI takes its secret
from a file named by `-token-file`, defaulting to `$MYTOOL_TOKEN_FILE`, and falls back to
`$MYTOOL_TOKEN` when neither is set. Document the fallback as what it is: convenient, and
readable by every child process the shell starts. The ban above is scoped to services, not
softened — `$CREDENTIALS_DIRECTORY` only exists where a deployment does.

## Testing

`parseConfig` takes its arguments and writes to an injected `stderr`, so it tests without
a process: call it with an `args` slice and `io.Discard`, and set the environment half
with `t.Setenv` — which restores the variable afterwards and forbids `t.Parallel`.

Table-test what can actually break: **precedence** (a flag overrides its environment
variable), each **validation failure**, **each half of a paired setting** from rule 7,
and the **empty environment** case from rule 3. Precedence regresses most silently,
because a wrong answer still starts. One more test earns its place the moment the struct
holds a secret: set one, render the config through a `slog` handler, and assert the value
does not appear — that is what catches the field somebody adds to `Config` and forgets to
leave out of `LogValue`. Log a struct that *contains* the config too, because the first
case passes on `LogValue` alone and only the second one proves the field's type.

## Anti-patterns

- ❌ viper, koanf, envconfig, godotenv. Twenty lines of stdlib, and none are on the
  approved list in [stack/go.md](../stack/go.md).
- ❌ A config file. Flags and environment cover both ways a binary gets configured; a
  file adds a format, a path, a reload question, and a second place for the answer to
  live. When a project genuinely needs one, it is one flag pointing at one file — and the
  flag still wins over the file.
- ❌ A package-level `var cfg Config`. Global mutable state, initialized by `init()` in
  the worst version, untestable in every version.
- ❌ `log.Fatal` inside the parser. It skips deferred cleanup and cannot be tested;
  return the error and let `main` own the exit code.
- ❌ Defaulting a secret (`cmp.Or(os.Getenv("SMTP_KEY"), "dev-secret")`). The default
  ships to production the day somebody forgets to configure the real one.
- ❌ A secret in an environment variable or a **committed** `.env` file. An
  *uncommitted* `.env` that `make run` sources
  ([stack/makefile.md](../stack/makefile.md) rule 6) is a different thing: a developer's
  own machine, gitignored, and never how a deployment gets a secret. The word doing the
  work in this bullet is *committed*.
