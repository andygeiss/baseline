# Pattern: File Uploads (Go)

**Tier 1** (safety — never waived) · Last verified: 2026-08-27

Refusing the client's filename and the client's content type, deciding the type by
sniffing the bytes, serving every file through a handler rather than a file server, and
the `Content-Disposition` default are tier 1. Rule 1 below, where the bytes live, and how
orphans are swept are tier 2: getting any of those wrong loses a field or leaves garbage,
and neither hands anything over.

[go-authorization.md](go-authorization.md) rules rows. **A file is a row and a URL, and
the URL is where those rules stop applying.** A static file server has no actor to name,
and a browser handed the wrong content type runs what it was sent. Both failures pass
every other box in the checklist.

## Taking the bytes

The route raises its own cap at the cap site — never by widening the blanket 1 MiB, which
cannot be raised downstream ([go-http-server.md](go-http-server.md) rule 6). In the
middleware, before delegating to the mux:
`limit := int64(1<<20); if r.URL.Path == "/upload" { limit = 32<<20 }; r.Body = http.MaxBytesReader(w, r.Body, limit)`.

```go
// ParseMultipartForm, not ParseForm — see rule 1 below. Its argument is how
// much to keep in memory before the rest spills into os.TempDir(); passing the
// cap itself means nothing ever spills, so there is no temp file to get wrong.
// (net/http removes those files when the handler returns, which is why nothing
// may keep the form past this request.)
if err := r.ParseMultipartForm(maxUpload); err != nil && !errors.Is(err, http.ErrNotMultipart) {
	status := http.StatusBadRequest
	if _, ok := errors.AsType[*http.MaxBytesError](err); ok {
		status = http.StatusRequestEntityTooLarge // the route's own cap
	}
	a.clientError(w, r, status)
	return
}

f, fh, err := r.FormFile("file")
// Two ways to have sent nothing, and both are ordinary: a multipart form with
// the field left empty, and a plain urlencoded post with no file part at all.
// Neither is an error, and the message posts without an attachment.
if errors.Is(err, http.ErrMissingFile) || errors.Is(err, http.ErrNotMultipart) {
	a.post(w, r, form, nil, nil)
	return
}
if err != nil {
	a.serverError(w, r, err)
	return
}
defer f.Close()

// Neither of the two things the browser said is read. fh.Header's Content-Type
// is its claim about a file somebody picked on their own machine; fh.Filename
// is their text, kept for the download header and nothing else. The bytes
// decide, and the stored name is generated.
bs, err := io.ReadAll(io.LimitReader(f, maxUpload+1)) // +1: over the cap is a rule, not a silent truncation
if err != nil {
	a.serverError(w, r, err)
	return
}
kind := http.DetectContentType(bs)
if !allowedUpload[kind] { // an exact set — never a prefix test on "image/"
	form.Check(false, "file", "Attach a picture, a PDF, or a text file.")
	a.renderInvalid(w, r, form)
	return
}
att := newAttachment(rand.Text(), actor, cleanName(fh.Filename), kind, int64(len(bs)))
a.post(w, r, form, att, bs)
```

⚠️ **Reading it all is why there is no seek here.** Sniff off a stream and store what is
left, and every file bigger than 512 bytes arrives missing its head — only the small ones
survive to prove it. If the file is too big to hold, seek back before storing:
`multipart.File` is a `ReadSeeker`, so `f.Seek(0, io.SeekStart)` always works.

The rules behind it — all MUST:

1. **`ParseForm` is not enough on a route that takes a file.** On a multipart request it
   leaves `PostForm` non-nil and empty, so every `PostFormValue` after it answers `""` —
   the field is on the wire and gone in Go, with no error anywhere. Call
   `ParseMultipartForm`, and read its `http.ErrNotMultipart` as "a plain form post".
   `FormFile` answers the same way, so `ErrMissingFile` and `ErrNotMultipart` both mean
   nothing was attached.
2. **The stored name is generated, never derived from the client's.** A generated id, or
   the row's own id. `filepath.Base` is not a fix: it knows the separator this process
   runs on, and a browser on Windows sends the other one. Keep the original in a column,
   cleaned of control characters, for the download header and nothing else.
3. **The type is what the bytes say.** `http.DetectContentType` reads at most 512 bytes,
   always answers, and falls back to `application/octet-stream`. Store its answer; that
   stored string is what the download sends back.
4. **The allowlist is an exact set of types the app accepts.** A prefix test on `image/`
   admits every type a future sniffer learns. **SVG is never on it** — an SVG is a
   document that can carry script, and Go's sniffer does not classify it as an image, so
   an exact image allowlist already excludes it. Keep it that way on purpose.
5. **A refused upload re-renders the form** with the error, like any other invalid POST
   ([go-forms-validation.md](go-forms-validation.md)). Over the cap answers 413.
6. **The row records who uploaded it, the stored name, the original name, the sniffed
   type, the size, and when.** The uploader column is what lets
   [go-authorization.md](go-authorization.md) rule any of this; the timestamp is what
   `http.ServeContent` sends as `Last-Modified`.

## Where the bytes live

Two answers, and the project picks one and writes it in the README. **Pick by the backup
answer [go-sqlite.md](go-sqlite.md) already forced you to give**, because that is the
difference that bites:

| | Bytes in a SQLite `BLOB` | Bytes in a directory |
|---|---|---|
| **Backups** | The backup you already have covers them. | A second thing to copy off the box; `VACUUM INTO` cannot see them. |
| **Atomicity** | The row and the bytes commit together. | Two writes that can disagree — hence the delete order below. |
| **Good for** | Avatars, attachments, anything small. | Files big enough that holding one in memory is a problem. |

Bytes on disk are written to a temp file in the **same directory** and renamed into place
— `os.Rename` is atomic within a filesystem and fails across one.

**A blob has no delete order and needs no sweeper** — the row *is* the bytes, so they
cannot disagree. That is most of why the blob answer wins for small files.

**On disk, delete the row first and the bytes second.** A row whose bytes are gone is a
broken download the reader sees; bytes whose row is gone are garbage nobody sees. Only one
of those is safe to have, so a janitor sweeps files with no row
([go-background-work.md](go-background-work.md)).

**Deleting the person who uploaded them keeps that order and adds a step**, because the
cascade takes the row away before you can ask it which files were theirs: the names are
collected first ([go-data-deletion.md](go-data-deletion.md)).

## Serving them back

**Every download goes through a handler.** Never `http.FileServer` over the upload
directory: it names no actor, and it types files by extension.

```go
// Files are owned in this app, so the row is fetched with the actor in the
// query, exactly like any other owned row — that query is the whole access
// control, and the filename is not part of it. Shared files: see below.
file, content, err := a.files.Open(r.Context(), actor, r.PathValue("id"))
if errors.Is(err, domain.ErrNotFound) { // a stranger's file and a missing one, alike
	a.clientError(w, r, http.StatusNotFound)
	return
}
if err != nil {
	a.serverError(w, r, err)
	return
}
defer content.Close()

w.Header().Set("Content-Type", file.Kind) // sniffed at upload, never the extension
if !inlineOK[file.Kind] {
	// FormatMediaType quotes the name and RFC 2231-encodes a non-ASCII one. A
	// raw filename here is header injection, and it breaks the first download
	// of a file called `report "final".pdf`.
	w.Header().Set("Content-Disposition",
		mime.FormatMediaType("attachment", map[string]string{"filename": file.Name}))
}
// ServeContent deduces a type from the name only when Content-Type is unset,
// so the name is empty here: an extension must never overrule the sniffed type.
http.ServeContent(w, r, "", file.UploadedAt, content)
```

- **`inlineOK` is shorter than the upload allowlist.** Only the types the app renders in
  its own pages — the images in an `<img>` — are served inline. Everything else is an
  attachment, so a browser that would have rendered it downloads it instead.
- **`X-Content-Type-Options: nosniff` is what makes the stored type binding**, and
  `secureHeaders` already sends it on every response
  ([security-headers.md](security-headers.md)). Without it a browser may sniff its way
  past the type you chose.
- **The policy needs no change**, and [security-headers.md](security-headers.md) owns
  saying so: uploads load nothing from anywhere new. Add a row to the record it points at
  when that stops being true.
- **`http.ServeContent` gives range requests and conditional GETs for free.** The store
  returns the row and a `ReadSeekCloser` beside it — a `*os.File`, or a blob wrapped in a
  `bytes.Reader`. Which one the caller gets is the storage choice, and the handler above
  does not know which it made.

**When the file is not owned, say so — and keep the rest.** An attachment in a room
everyone may read has no actor predicate, and that is correct:
[go-authorization.md](go-authorization.md) *Say which rows are shared* covers it, and a
file inherits the answer of the row it hangs on. Two things do not change. It is still a
handler and never a file server. And **deleting is not reading**: the actor comes back for
that, in the `WHERE` clause, so somebody else's file answers like one that never existed.

## If the app decodes an image

Decode dimensions before pixels. `image.DecodeConfig` reads the header only, so a
64000×64000 PNG that would allocate gigabytes is refused for the cost of a few bytes.
Cap width times height, then decode. Only the stdlib decoders — an image library is a
parser written in C, run on a stranger's file.

## Testing

- **The two-user test, on whichever operation is owned**
  ([go-authorization.md](go-authorization.md)). Where files are owned outright, a second
  signed-in user asks for the first one's file id and gets 404. Where reading is shared,
  the test moves to the delete: the second user's delete answers exactly like a delete of
  a file that was never there, and the file is still there afterwards.
- **An upload that lies.** Post a file named `avatar.png`, declared `image/png`, whose
  bytes are `<svg onload=…>`. **Assert what it is never served as**, not that it is
  refused: an app whose allowlist has `text/plain` on it stores that file as text and
  hands it back as an attachment, which is safe, and an app without stores nothing.
  Both pass; "refused" only passes one of them. This is the test that proves the sniff
  is load-bearing, and it fails the day somebody trusts `fh.Header`.
- **A download of an allowed non-inline type** carries `Content-Disposition: attachment`.
- **A round trip is byte-identical**, for a file well over 512 bytes — the regression test
  for a sniff that ate the head.

## Anti-patterns

- ❌ `http.FileServer` or `http.Dir` over the upload directory. No actor, no type control,
  and path traversal is then one `filepath.Join` away.
- ❌ Trusting `fh.Header.Get("Content-Type")` or the extension. Both are the client's.
- ❌ An unguessable filename as the permission. A file URL travels further than a row id:
  it lands in `<img src>`, in referrer headers, and in whatever the reader pastes.
- ❌ Serving user files from the app's origin as `text/html` or `image/svg+xml`. That is
  same-origin script, and the session cookie is right there.
- ❌ Resizing or transcoding with ImageMagick, or any CGO image library. `CGO_ENABLED=0`
  is the project's build; a media pipeline is a different shape of application.

## Facts verified (2026-09-05)

- `DetectContentType` "considers at most the first 512 bytes" and returns
  `application/octet-stream` when it cannot decide:
  https://pkg.go.dev/net/http#DetectContentType
- Go's sniffing table has signatures for GIF, PNG, JPEG, WEBP, BMP and ICO, and none for
  SVG: https://mimesniff.spec.whatwg.org/#matching-an-image-type-pattern
- `ServeContent` uses the name to deduce a type only "if the response's Content-Type
  header is not set": https://pkg.go.dev/net/http#ServeContent
- The server removes multipart temp files after the handler returns —
  `finishRequest` calls `MultipartForm.RemoveAll`:
  https://cs.opensource.google/go/go/+/refs/tags/go1.27.1:src/net/http/server.go
- `mime.FormatMediaType` quotes parameter values and encodes non-ASCII ones per RFC 2231:
  https://pkg.go.dev/mime#FormatMediaType
- `ParseForm` on a multipart body reads nothing and leaves `PostForm` non-nil and empty
  — `parsePostForm`'s multipart case is empty, and `PostFormValue` then skips
  `ParseMultipartForm` because `PostForm != nil`:
  https://cs.opensource.google/go/go/+/refs/tags/go1.27.1:src/net/http/request.go
