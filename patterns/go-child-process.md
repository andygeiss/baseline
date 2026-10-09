# Pattern: Child Process (Go)

**Tier 2** (shape — waived only on the record) · Last verified: 2026-10-09

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
signal.Ignore(syscall.SIGTTOU) // inherited: under stty tostop, a write would stop the child
signal.Ignore(syscall.SIGTSTP) // Ctrl-Z must not stop the one process that can stop the child
if err := cmd.Start(); err != nil {
	return fmt.Errorf("start the engine: %w", err)
}
done := make(chan struct{})                 // closed once the child has exited
go func() { _ = cmd.Wait(); close(done) }() // its exit is cmd.ProcessState, read after done
var once sync.Once
stopChild := func() {
	once.Do(func() {
		// The whole group, so its helpers stop too; ESRCH means all of them are gone.
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGTERM)
	})
}
defer func() { // every return waits for the child, early ones too
	stopChild()
	select {
	case <-done:
	case <-time.After(grace): // it outlasted the stop signal: nothing survives this one
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
		<-done
	}
}()
```

- **Its own process group.** A Ctrl-C goes to every process in the terminal's foreground
  group. A child in that group gets it too, so the tool's own stop arrives as a second
  signal, and a program that unwinds on every signal can cut its cleanup short. The price:
  Ctrl-\ and Ctrl-Z now reach the tool alone, and a quit leaves the child running.
- **SIGTTOU and SIGTSTP ignored before `Start`.** In its own group the child is a
  background job: under `stty tostop` its first write to the terminal would stop it, and
  the tool's SIGTERM would then sit pending while the tool waits. Ctrl-Z would stop the
  tool alone, leaving the child running with nobody to stop it — and on macOS a stopped
  Go program misses the `kill %1` or hangup meant to end it. The child inherits both: an
  ignored signal stays ignored across `exec`.
- **Unix only.** `Setpgid` and `syscall.Kill` do not exist on Windows: keep this code
  behind `//go:build unix`. A tool that must also run there gives Windows a file of its
  own, which `GOOS=windows go vet` then checks ([operations/ci.md](../operations/ci.md)).
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
	failed = context.Cause(ctx) // names the signal: an interrupted run exits non-zero
case <-done:
	failed = fmt.Errorf("the engine stopped on its own: %v", cmd.ProcessState)
}
stopChild() // before the tool's own shutdown, not after it
// … the tool's own shutdown …
return failed // the deferred wait holds this until the child is gone
```

- **Stop it before the tool's own shutdown.** That shutdown can take seconds, and a
  second Ctrl-C meanwhile ends the tool at once — [go-cli.md](go-cli.md)'s force-kill
  hatch. A child not yet asked to stop then runs on with nobody to stop it; one that was
  asked stops by itself, unless it ignores the signal.
- **One stop signal to the whole group**, SIGTERM unless the child documents another as
  its graceful stop. Every process in the group gets it once, as a Ctrl-C would have
  reached them, so a helper the child started stops with it. `sync.Once` keeps it at one
  when several paths stop the child.
- **A bounded wait.** A group still running `grace` after its stop signal gets SIGKILL;
  set `grace` to the longest the child's own graceful stop takes, with a margin. Without
  it, a child that ignores SIGTERM keeps the tool waiting for ever — and after a terminal
  closes, with SIGHUP ignored, nothing is left that can end either of them.
- **A child that stops on its own stops the tool**, with an error naming the exit: a
  proxy in front of nothing is worse than no proxy.
- **SIGHUP stops the tool too.** In its own group the child no longer hears the terminal
  close, and Go's default for SIGHUP ends the tool without stopping the child. Add
  `syscall.SIGHUP` to the `signal.NotifyContext` call unless `signal.Ignored` reports it:
  that is `nohup` asking, and `Notify` would undo it. A closing terminal can send SIGHUP
  twice, so [go-cli.md](go-cli.md)'s force-kill hatch ignores it before it unregisters the
  rest — `<-ctx.Done(); signal.Ignore(syscall.SIGHUP); stop()` — or the second one ends
  the tool before the child has.

## Testing

The test binary plays the child: a real process, real signals, a real loopback socket.

```go
func TestMain(m *testing.M) {
	if mode := os.Getenv("FAKE_ENGINE"); mode != "" {
		os.Exit(fakeEngine(mode)) // listens, answers readiness, logs each signal it gets
	}
	os.Exit(m.Run())
}
```

Start it as `os.Executable()` with `FAKE_ENGINE` in its `Env`, one mode per behavior:
ready after a few asks, never ready, failing at once, outlasting SIGTERM. Add
`GORACE=atexit_sleep_ms=0`: under `-race` the fake is race-built, and otherwise sleeps a
second as it exits. The fake appends each signal it catches to a file its `Env` names,
and the test reads that file once `run` has returned: SIGTERM, and complete, because
`run` waited. For the fake that outlasts SIGTERM, `run` returning at all shows the
SIGKILL. The file cannot count sends — two signals close together can arrive as one — so
`sync.Once` keeps that count, not the test. `grace` and the poll interval are
parameters, so the tests take milliseconds. None sleeps, and none runs inside
`synctest`: a goroutine waiting on a process, like one on a socket, is never durably
blocked ([go-testing.md](go-testing.md)).

## Facts verified (2026-10-09)

- INTR "Generates a SIGINT signal which is sent to all processes in the foreground
  process group": https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap11.html
- A controlling process that exits sends SIGHUP "to each process in the foreground
  process group of the controlling terminal":
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/_exit.html
- `CommandContext` "sets Cancel to call the Kill method"; any non-nil `Stdout` but an
  `*os.File` makes `Wait` wait for the pipe to reach EOF, or for a nonzero `WaitDelay`:
  https://pkg.go.dev/os/exec#Cmd
- "A SIGHUP, SIGINT, or SIGTERM signal causes the program to exit", and `Notify` on a
  SIGHUP the program started ignoring means it "will no longer be ignored":
  https://pkg.go.dev/os/signal
- `context.Cause` on a `NotifyContext` a signal cancelled "will return an error describing
  the signal": https://pkg.go.dev/os/signal#NotifyContext
- A `pid` that is negative, but not -1, sends the signal "to all processes … whose process
  group ID is equal to the absolute value of pid":
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/kill.html
- Under TOSTOP, a process "ignoring the SIGTTOU signal … is allowed to write to the
  terminal": https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap11.html;
  and "signals set to be ignored (SIG_IGN) by the calling process image shall be set to be
  ignored by the new process image":
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/exec.html
- Closing a terminal under zsh 5.9 delivers SIGHUP twice, about a millisecond apart; bash
  3.2 delivers it once — measured on this Mac.
- After Ctrl-Z and `kill %1`, a Go 1.27 tool on this Mac never sees the SIGTERM; with
  SIGTSTP ignored, Ctrl-Z leaves it in the foreground — measured.
- "If a subsequent occurrence of a pending signal is generated, it is implementation-defined
  as to whether the signal is delivered or accepted more than once":
  https://pubs.opengroup.org/onlinepubs/9799919799/functions/V2_chap02.html
- `atexit_sleep_ms` "(default 1000): Amount of milliseconds to sleep in the main goroutine
  before exiting": https://go.dev/doc/articles/race_detector#Options
