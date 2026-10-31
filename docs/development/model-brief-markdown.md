# Share one saved model investigation

Select a `rails_model` fact ID and an explicit saved generation, then run:

```sh
thistle export-model-brief MODEL_ID --store STORE --generation GENERATION_ID
```

The command writes one deterministic UTF-8 Markdown report to stdout. Errors use
existing CLI JSON on stderr and a nonzero status. It never falls back to CURRENT
when a generation is absent or unavailable. It opens one pinned Reader, calls
`model_brief` once, and closes the Reader before writing the completed report.
It follows no references, source files, family pages or other generations.

The report preserves Rust's selected model, column, association, registered
callback and reference families, their order, scoped omitted counts, partiality
and unknowns. Missing provenance stays unknown. Schema and allowlisted producer
and grammar fields come from the already opened manifest; its file inventory is
not scanned. Ruby supplies presentation only; it does not select or analyze facts.
A label candidate is not a canonical binding. Registered callbacks, source-supported
potential requests and execution are distinct; nothing asserts execution,
delivery, conditions, order, runtime/source coherence or live freshness.

## Resolve references

Reports contain literal `thistle source` and `thistle links` commands with fact
IDs and the exact generation. Method and call spans use the returned half-open
byte coordinates and line coordinates; available source digests identify saved
bytes. Relationship rows retain origin IDs, link ordinals, candidate identities
and candidate-search scope. Family follow-ups restart the existing bounded JSON
query at that generation; the report does not embed a continuation cursor.

Replace `STORE` with a local store you are authorized to read, using normal shell
quoting. Recipients need a compatible installed Thistle and access to that saved
generation and its referenced blobs. A report alone cannot resolve those bytes.
Observed facts without source positions may have no source destination. Copying
or removing a store is outside this command. No trusted web base is configured,
so the renderer creates no web links or inferred repository URLs.

No full source, excerpts, arbitrary attributes, link metadata, callback condition
values, original absolute callback descriptor paths or store paths are embedded.
Allowlisted names and status text render as inert code spans. Control characters,
line/paragraph separators and the bidi embedding/isolate ranges are made visible;
other format characters and literal backslashes remain as supplied. Literal
backslash escape text can therefore resemble a displayed control escape.
Scheme-bearing URLs and absolute/home path text are withheld. Scheme-less URL
shapes may remain as inert label text. Invalid UTF-8 or unsupported
response shapes refuse the report rather than repairing evidence. This is a
bounded evidence projection, not a general secret scanner: review the selected
application labels before sharing them, as with any source-derived report.

## Bounds and caller-owned output

`--limit` uses the current model-brief admission: 8 rows per family by default,
1–16 allowed. `--max-bytes` defaults to 32768 and permits 1–65536. The same explicit
ceiling applies separately to the Reader's JSON response (including its newline)
and the entire encoded Markdown report. Markdown headings, commands, control
escapes, code fences and the final newline all count. Escaping can make a report
larger than the selected JSON response. The formatter refuses with
`limit_exceeded` if it cannot fit every report field; it never silently drops
additional rows or changes Rust's omission counts. Try a smaller `--limit` or a
larger allowed `--max-bytes`.

The report is buffered within its ceiling and emitted only after successful
formatting and Reader close. An output-device failure still returns nonzero, but
a sink can have accepted some bytes before failing; stdout is not a filesystem
transaction. Shell redirection is explicitly caller-owned:

```sh
thistle export-model-brief MODEL_ID --store STORE --generation GENERATION_ID > brief.md
```

The shell may create or truncate that file even on refusal. Choose its location,
permissions and overwrite behavior yourself, and check the command's status.
The command manages no vault, directory, sync, upload or persistent export state.

## Fit and maintenance

The [pinned Woods product documentation](https://github.com/lost-in-the/woods/blob/fccb95782e38dd072a016d317a8e8ca782580b11/docs/MARKDOWN_EXPORT.md)
provides the conceptual precedent of portable local evidence-linked Markdown.
No Woods engine/exporter code or text is copied; no new third-party attribution
or license dependency is introduced. Bulk vault management and publication are
outside this slice.

Existing Thistle CLI errors and the bounded Reader response are reused. A general
Markdown parser/serializer adds a dependency and output policy without helping
this fixed heading/list/code-span vocabulary. The small handwritten renderer
keeps one allowlist and no parser, template framework or new dependency. It
appends to one bounded buffer and visits selected rows and allowed scalar text
linearly, without repeated whole-report serialization, source expansion or store
scans. Fixed Reader response limits bound escape/fence scratch allocations; the
report-byte ceiling is not a process RSS or latency claim. Review the allowlist
when model-brief version/shape changes; unknown report versions refuse. Reconsider
a maintained serializer if export needs richer Markdown or multiple formats.

Pure formatter and mocked CLI regressions cover escaping, malformed text,
refusals, deterministic ordering, byte bounds and lifecycle. Run the pure/mock controls without native loading using:

```sh
ruby -Ilib -Itest -r./test/test_cli.rb -e '' -- --exclude /native_saved_generation/
```

The separately admitted real journey is
`ThistleMarkdownExportSavedGenerationTest#test_native_saved_generation_report_is_identical_after_current_advances`
in `test/test_cli.rb`; it boots the Rails fixture and captures two generations.
It is deliberately excluded from the source-only command above.

Real Reader pinning,
a saved-generation report after CURRENT advances, and changed installed Core
contracts require separate native/package evidence. Passing pure checks does not
establish those gates or qualify L13; all 17 launch requirements remain unqualified.
