# Pattern: Child Process (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-10-04

**One rule here is tier 1 and never waived:** a secret never travels on the child's
command line, because `ps` shows every argument to every user. The child reads it from a
file, or, when it reads nothing but its environment, from its own environment alone.

A program the tool starts and keeps running beside itself — a server it fronts, an
inference engine, a database for a test run — and stops again. A program it runs to
completion (`git`, `make`) needs none of this: `exec.CommandContext` and the exit status
are the whole contract. **The tool owns the child: it decides when the child stops, asks
it once, and does not exit before the child has.**

## Start it in a process group of its own

```go
cmd := exec.Command(path, args...)
cmd.Env = append(os.Environ(), "ENGINE_KEY="+key) // the child's alone, never os.Setenv
cmd.Stdout, cmd.Stderr = os.Stderr, os.Stderr     // the tool's stdout is data
cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
if err := cmd.Start(); err != nil {
	return fmt.Errorf("start the engine: %w", err)
}
done := make(chan struct{}) // closed once the child has exited
go func() { _ = cmd.Wait(); close(done) }()
var once sync.Once
stop := func() { once.Do(func() { _ = cmd.Process.Signal(syscall.SIGTERM) }) }
defer func() { stop(); <-done }() // every return waits for the child, early ones too
```

- **Its own process group.** A Ctrl-C goes to every process in the terminal's foreground
  group. A child in that group gets it too, so the tool's own stop arrives as a second
  signal, and a program that unwinds on every signal can cut its cleanup short.
- **Not `exec.CommandContext`.** Its default cancel is `Process.Kill`: SIGKILL, which no
  cleanup survives.
- **The tool's own `*os.File` for the child's output.** Any other writer puts a pipe in
  between, and `Wait` then waits until every process holding that pipe is gone — a helper
  the child left running in the background included.
- **`Wait` runs once, in that goroutine.** Everything else selects on `done`, and reads
  `cmd.ProcessState` only after it.

## Wait until it is ready

Ask the child's readiness endpoint on a ticker, through a client with a timeout
([go-http-client.md](go-http-client.md)), until it answers. The wait ends three ways:
ready, `done` — the child's own output already says why — or `ctx.Done()`. A start with
no known bound, a model loading or a first download, gets no deadline; Ctrl-C is the
deadline.

**Check what can fail fast before `Start`:** the flags, the files, and the port the tool
itself listens on — take it first. A start that costs minutes must not end on a typo or a
port already in use.

## Stop it first, once, and wait

```go
var failed error
select {
case <-ctx.Done(): // Ctrl-C, SIGTERM or SIGHUP reached the tool
case <-done:
	failed = fmt.Errorf("the engine stopped on its own: %v", cmd.ProcessState)
}
stop() // before the tool's own shutdown, not after it
// … the tool's own shutdown …
return failed // the deferred wait holds this until the child is gone
```

- **Stop it before the tool's own shutdown.** That shutdown can take seconds, and a
  second Ctrl-C meanwhile ends the tool at once — [go-cli.md](go-cli.md)'s force-kill
  hatch. A child not yet asked to stop then runs on with nobody to stop it; one that was
  asked finishes stopping by itself.
- **One stop signal**, SIGTERM unless the child documents another as its graceful stop,
  and `sync.Once` keeps it at one when several paths stop the child.
- **A child that stops on its own stops the tool**, with an error naming the exit: a
  proxy in front of nothing is worse than no proxy.
- **SIGHUP stops the tool too.** In its own group the child no longer hears the terminal
  close, and Go's default for SIGHUP ends the tool without stopping the child. Add
  `syscall.SIGHUP` to the `signal.NotifyContext` call unless `signal.Ignored` reports it:
  that is `nohup` asking, and `Notify` would undo it.

## Testing

The test binary plays the child: a real process, real signals, a real loopback socket.

```go
func TestMain(m *testing.M) {
	if mode := os.Getenv("FAKE_ENGINE"); mode != "" {
		os.Exit(fakeEngine(mode)) // listens, answers readiness, exits on SIGTERM
	}
	os.Exit(m.Run())
}
```

Start it as `os.Executable()` with `FAKE_ENGINE` in its `Env`, one mode per behavior:
ready after a few asks, never ready, failing at once. Assert the exit a stop produced: a
fake that exits with 128 plus the signal shows SIGTERM, where a kill shows
`signal: killed`. The poll interval is a parameter, so the tests take milliseconds. None
sleeps, and none runs inside `synctest`: a goroutine waiting on a process, like one on a
socket, is never durably blocked ([go-testing.md](go-testing.md)).

## Facts verified (2026-10-04)

- INTR "Generates a SIGINT signal which is sent to all processes in the foreground
  process group": https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap11.html
- A controlling process that exits sends SIGHUP "to each process in the foreground
  process group of the controlling terminal":
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/_exit.html
- `CommandContext` "sets Cancel to call the Kill method"; any `Stdout` but an `*os.File`
  makes `Wait` wait for the pipe to reach EOF: https://pkg.go.dev/os/exec#Cmd
- "A SIGHUP, SIGINT, or SIGTERM signal causes the program to exit", and `Notify` on a
  SIGHUP the program started ignoring means it "will no longer be ignored":
  https://pkg.go.dev/os/signal
