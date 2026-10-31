# Saved fact identity

`Reader#fact_identity(id)` returns one exact saved identity with its generation:
`generation` and `fact` (`id`, `kind`, `name`, `path`, `location`, `evidence`).
Location is null or its four recorded byte/line bounds. It is recorded evidence,
not a runtime binding, execution observation or live working-tree check.

Open the Reader with an explicit saved generation for reproducible navigation.
An absent fact raises `not_found`; invalid IDs and closed Readers retain their
ordinary errors. A missing generation never becomes CURRENT when explicitly
requested. Close the Reader in an ensure block.

The Rust operation uses the ID index already admitted by Reader open. It does
not expand links, attributes or source, or build the optional recorded-name,
method or source directories. The fixed response has a 32 KiB encoded JSON
result ceiling, counted over borrowed fields before output materialization;
512 KiB query scratch is reserved through response serialization. Refusal
returns no successful partial identity. These are encoded-data/copy allowances,
not complete heap or RSS measurements. Reader open still validates and indexes
the saved domain; this operation does not make the whole job constant-cost.

This narrow primitive serves bounded selected-fact Map investigations. Using
`references(limit: 1)` for identity would additionally resolve a relationship
and could construct/sort the entire optional recorded-name directory. Returning
`fact` would expand all its links. An allowlisted Rust projection avoids both
costs without teaching Ruby to inspect stored wire data or introducing a second
cache. Callers must separately bound selection count, aggregate output and page
work; there is no inventory operation or batch query in this primitive.

The additive native operation requires its own compatible changed Core/native
artifact evidence. The old Core469a/native4bee result does not cover it.
