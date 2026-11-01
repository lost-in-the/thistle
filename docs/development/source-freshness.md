# Explicit saved-file source freshness

`Reader#source_freshness(file_path, workspace_root: nil, max_bytes: 2097152)`
compares one captured relative file's recorded SHA-256 and byte count with an
explicitly supplied workspace. It does not read a saved source blob. Ordinary
`source`, `source_file` and `check` retain their existing behavior. `check` still
reports source freshness as `not_checked`, even after this explicit comparison.

The caller chooses the allowed root. It must be a nonempty absolute path other
than `/`, with no empty, dot, parent, backslash or control-character components.
There is no default from the manifest, process directory or browser. `nil`
performs one pinned metadata lookup and **zero live filesystem operations**.
The selected path must exist in this Reader's already validated file metadata
before any workspace access. An invalid path or absent selected file is a native
error (`unsafe_path` or `not_found`), never a comparison with another file.

## Version 1 result

The result contains `version: 1`, the pinned `generation`, and
`file: {path, sha256, bytes}` from the saved metadata, plus `status`, `reason`,
`usage`, `limits` and a fixed `scope` explanation. It contains no live source
bytes, snippets, live digest, absolute workspace root, resolved host paths or
raw filesystem error text. File identity here means the selected saved
generation/path/digest/size; host inode information is private comparison state.

| Status | Reason | Meaning |
| --- | --- | --- |
| `not_checked` | `workspace_root_not_supplied` | No live workspace was supplied or accessed. |
| `matching` | `recorded_digest_matches` | All admitted file bytes matched the recorded size/digest and stability checks passed. |
| `changed` | `recorded_digest_differs` | A complete admitted stable file differed in size or digest. |
| `unverifiable` | `unsafe_root` | Root spelling is relative, `/`, traversing or otherwise unsafe. |
| `unverifiable` | `root_limit`, `path_limit` | Root bytes/depth or selected path depth exceeds admission. |
| `unverifiable` | `missing` | A required workspace entry was absent during initial admission. |
| `unverifiable` | `unreadable` | Initial descriptor/metadata access failed, including permission refusal. No raw error is exposed. |
| `unverifiable` | `unsafe_path_or_nonregular` | A symlink, nondirectory ancestor or nonregular leaf was refused during admission. |
| `unverifiable` | `byte_limit` | The admitted regular file size exceeds the caller's read allowance. No source bytes were read. |
| `unverifiable` | `read_failed`, `interrupted` | Reading or a test-only I/O injection failed; interruption is not retried. |
| `unverifiable` | `incomplete_read` | EOF arrived before the stat size, or the explicit EOF probe found additional bytes. |
| `unverifiable` | `concurrent_change` | Descriptor metadata or a named path identity changed, disappeared or could not be revalidated. |
| `unverifiable` | `work_limit` | The finite filesystem-attempt allowance was exhausted. |
| `unverifiable` | `unsupported_platform` | The existing descriptor directory layer refused the platform. |

Malformed types and `max_bytes` outside integer `0..4194304` are native
`invalid_input` errors. Exhaustion of the existing global Reader/query scratch
budget is a native `limit_exceeded` error **before workspace I/O**, not a
matching result. No partial or refused operation means unchanged.

## Descriptor and race strategy

Rust borrows one selected metadata row from the Reader's existing path map.
It opens `/`, then each absolute root ancestor and relative parent through
`fs::Dir` descriptor-relative `openat` with `O_DIRECTORY | O_NOFOLLOW`.
The leaf uses the same reusable descriptor-open primitive as snapshot reads:
`O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC`, then regular-file admission by `fstat`.
Snapshot reads keep their existing regular-file check. No directory scanning,
canonicalization, symlink resolution, capture, app execution or network occurs.

Rust retains the directory chain, descriptor identities and initial leaf stat.
It hashes bounded chunks through the initial regular-file size (including zero),
checks the leaf's device/inode/size/mode/links/owner/mtime/ctime afterward, and
reopens every named ancestor edge relative to its original parent. Directory
device/inode identity must match. The final reopened leaf must match the initial
file stat. Missing or unsafe entries during revalidation are concurrent change.
An explicit one-byte EOF probe must also return zero: stat size alone does not
establish complete content for every regular-looking filesystem entry. The
probe can read at most one additional byte on an unverifiable attempt. Its actual
bytes and read attempt remain charged. This prevents a synthetic zero-size file
from silently matching an empty recorded digest.

These checks detect observable replacement, growth, shrink and metadata changes.
They cannot make a multi-step filesystem observation atomic, detect every
change-and-restore or protect against a hostile filesystem that conceals changes.
A file or path can change after its final check. Matching is a bounded
point-in-time observation, not an atomic whole-workspace snapshot, future
freshness promise, CURRENT comparison, verified saved-blob integrity or proof
that loaded Ruby/Rails code corresponds to source. Use `check` for saved integrity.

## Cost, limits and reuse

The default 2 MiB read allowance can be lowered to zero or raised only to the
existing 4 MiB per-source content ceiling. `max_bytes` caps admitted content;
`eof_probe_bytes: 1` and `max_read_bytes: max_bytes + 1` separately bound the
possible probe on an incomplete attempt. Root and selected path each allow 4096 UTF-8
bytes and 64 components. A 16 KiB stack buffer streams bytes once into existing
`sha2`; there is no full-source copy or index. At most 128 directory descriptors
are retained in the chain. The original leaf and one temporary revalidation
descriptor bring the maximum simultaneously held descriptors to 130 (temporary
directories and reopened leaf are used in separate phases). Up to 1024 high-level
filesystem attempts are admitted. Each directory
open, file open, explicit stat and read increments its attempt counter immediately
before the operation; failed attempts remain charged. `bytes_read` and
`bytes_hashed` retain successfully processed bytes on failure. `metadata_lookups`
is one. `io_attempts` is the sum of the four attempt counters. These are logical
work counters, not a count of kernel-internal operations or I/O latency.

A conservative 256 KiB reservation uses the existing global Reader/query budget
and remains held through native response serialization. It covers bounded
descriptor-chain state, buffer, selected identity and result/serialization
storage; it is accounting, not a hard RSS or physical I/O limit. Source work is
O(root bytes + relative path bytes + admitted live bytes + component count),
with O(component count + chunk size) transient state. No speed, RSS or hard
filesystem-latency claim follows from these allowances; remote filesystems can
still stall an individual syscall despite nonblocking special-file admission.

The existing `fs::Dir`, `libc`, `sha2`, global reservation and public installed
producer/consumer pattern fit this bounded operation. A new filesystem package,
whole-workspace index or watcher would add dependencies/state without improving
the selected-file contract. Path-based canonicalize/read would lose descriptor
anchoring; loading `source_file` first would copy source and misleadingly couple
freshness to blob integrity. Root records this decision in the shared decisions
document at integration; this source writer does not edit that shared file.

## Evidence boundary

The Rust regression module authors deterministic test-only hooks for equal,
changed, empty, missing, injected unreadable/read failure, interrupted/incomplete
read, limits, root escape, symlink ancestors/root/parents/leaf, nonregular files,
file mutation/replacement and ancestor replacement. It also authors pinned A
after CURRENT B, unchanged Source/Check and a corrupt-blob independence case.
No production request flag activates a hook. The direct Ruby adapter double
uses no native extension, Rails or Active Record. The temporary installed
producer/consumer cards and served protocol are in
`test/fixtures/los143_source_freshness/`; native, installed and served execution
requires Root's later finite admission. Authoring those files is not execution.

This Core subresult does not complete LOS143's later visible Map freshness
action/result. Map LOS153 uses the existing public API independently. Root owns
integration, affected runtime gates and independent review; Leah owns applicable
acceptance. All 17 launch capabilities remain unqualified.
