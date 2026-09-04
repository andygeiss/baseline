# Pattern: Go Library

**Tier 2** (shape — waived only on the record) · Last verified: 2026-09-04

The mechanics behind [project-types/library.md](../project-types/library.md):
layout, doc comments, `Example` functions, fuzzing with a seed corpus, and the
release discipline that keeps the v1 promise. The project type defines the
rules; this document shows how to carry them out.

## Layout

A library is one package at the module root — no `cmd/`, no `internal/`
ceremony while it is a single package:

```
mylib/
├── example_test.go   ← Example functions (package mylib_test)
├── go.mod
├── LICENSE           ← MIT unless there is a reason otherwise
├── Makefile          ← stack/makefile.md with its rule-5 library adjustments
├── mylib.go
├── mylib_test.go     ← package mylib_test: the consumer's view (go-testing.md)
├── README.md
├── SPEC.md           ← the library's brief: job, why, guardrails, done means
└── testdata/
    └── fuzz/         ← committed seed corpus (see Fuzzing below)
```

Once the module genuinely grows more packages, detail moves under `internal/`
— the API design rules in [project-types/library.md](../project-types/library.md)
own that split. Directories are added when needed, never speculatively
([go-project-layout.md](go-project-layout.md)).

## Doc comments

pkg.go.dev renders these; they are the library's user interface. Two mechanics
matter beyond the godoc rules in [STYLE.md](../STYLE.md):

- The package doc comment sits on the `package` clause of the main file (or a
  dedicated `doc.go` when it outgrows a paragraph), states what the package
  does in its first sentence, and names the primary entry point with a doc
  link — `[Parse]` renders as a link on pkg.go.dev:

  ```go
  // Package semver parses and compares semantic version strings.
  //
  // [Parse] is the entry point; a parsed [Version] compares with
  // [Version.Less].
  package semver
  ```

- pkg.go.dev only renders documentation for modules with a recognized license
  — the `LICENSE` box in [checklists/library.md](../checklists/library.md) is
  what makes everything else in this section visible.

## Example functions

`example_test.go`, in the external test package. `go test` compiles every
example, and **runs** any example with an `// Output:` comment, asserting its
output — so the ordinary test gate keeps the documentation true. Write the
`// Output:` comment wherever output is deterministic; a compile-only example
(no comment) is the fallback for nondeterministic output, `// Unordered
output:` the middle ground:

```go
func ExampleParse() {
	v, err := semver.Parse("1.2.3")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(v.Major)
	// Output: 1
}
```

Naming binds the example to a symbol on pkg.go.dev: `Example` (package),
`ExampleParse` (function), `ExampleVersion_Less` (method),
`ExampleParse_prerelease` (a second example; suffix lowercase). Cover the main
entry points — the checklist demands it because these are the first code a
consumer copies.

## Fuzzing with a seed corpus

Any parser of untrusted input gets a fuzz test whose seeds encode the known
edge cases. Assert properties (no panic, round-trip stability), never exact
outputs:

```go
func FuzzParse(f *testing.F) {
	f.Add("1.2.3") // seed corpus: valid, empty,
	f.Add("")      // and known-tricky inputs
	f.Add("1.2.3-rc.1+build.5")
	f.Fuzz(func(t *testing.T, s string) {
		v, err := semver.Parse(s)
		if err != nil {
			return // rejecting bad input is success; panics and hangs are the bugs
		}
		v2, err := semver.Parse(v.String())
		if err != nil || v2 != v {
			t.Errorf("round-trip broke: %q → %v → %q", s, v, v.String())
		}
	})
}
```

- Plain `go test` (so `make check`) runs the function over the seeds —
  `f.Add` calls plus every file in `testdata/fuzz/FuzzParse/`. Only
  `go test -fuzz=FuzzParse`, run locally, explores new inputs.
- When fuzzing finds a failure it writes the input to
  `testdata/fuzz/FuzzParse/` — **commit that file.** It turns the crash into a
  permanent regression test that every future `go test` replays.

## Release mechanics

Semver tags `vX.Y.Z`, under the tag discipline of
[operations/cli-release.md](../operations/cli-release.md), with the library's
contract in place of the CLI's. Major = any of:

- Renaming or removing an exported symbol, changing a signature, or removing
  a struct field.
- Changing observable behavior consumers rely on.
- Adding a method to an exported **interface** — an implementor outside the
  module breaks unless it embeds the interface. (One more reason libraries
  accept interfaces and return structs: exported interfaces are rare on
  purpose.)

Additions (new function, method, field) are minor; fixes are patches.

- **Deprecate before removing:** a `// Deprecated: use [NewThing].` line above
  the old symbol keeps it working through the current major while consumers'
  staticcheck runs flag its uses. Removal waits for the next major — which is
  fought hard ([project-types/library.md](../project-types/library.md)).
- **A bad release is fixed forward** — never move or delete a published tag
  (the Rollback section of
  [operations/cli-release.md](../operations/cli-release.md) explains why). If
  a release is actively harmful, retract it in the next release's `go.mod`:

  ```go
  retract v0.4.0 // WithTimeout deadlocks; use v0.4.1
  ```

  The version stays downloadable, but `go` warns consumers who have it and
  `@latest` skips it.
- **`/v2`, when it truly cannot be avoided:** the module line becomes
  `module github.com/andygeiss/mylib/v2`, tags start at `v2.0.0`, and every
  consumer must edit its imports — the split that makes the project type call
  it a design failure to learn from.
