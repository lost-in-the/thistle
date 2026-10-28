# Third-party components

Thistle's original engine is newly written. It uses established libraries rather
than implementing a Ruby parser, JSON format, digest algorithm or compiler.

- Prism through ruby-prism / ruby-prism-sys 1.9.0: MIT, https://github.com/ruby/prism.
- serde / serde_json: MIT or Apache-2.0, https://github.com/serde-rs.
- sha2 and dependencies: MIT or Apache-2.0, https://github.com/RustCrypto/hashes.
- libc and transitive build dependencies retain their individual notices in
  `engine/vendor/`. Exact resolved versions are in `engine/Cargo.lock`.
- The optional Map gem records its approved Woods Map reuse separately in `map/`.

No Woods extraction, storage, query, MCP or evaluation implementation is used.
Cargo vendoring must preserve every package's distributed license files.
