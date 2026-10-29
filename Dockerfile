# Development-only toolchain; update these multi-architecture pins deliberately.
FROM rust:1.90.0-slim-bookworm@sha256:64232e656c058f4468e8d024e990acff04f0fd5a5c0a88a574dc37773d7325c9 AS rust
FROM rubylang/ruby:4.0.9-noble@sha256:00b39ba71c635939049654a87830f16ee3d40a856a46f09890e9f75ee49f6aec

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libclang-18-dev pkg-config git ca-certificates python3 python3-venv \
    && rm -rf /var/lib/apt/lists/*
COPY --from=rust /usr/local/rustup /usr/local/rustup
COPY --from=rust /usr/local/cargo/bin /usr/local/cargo/bin
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH=/usr/local/cargo/bin:$PATH
RUN rustup component add --toolchain 1.90.0 rustfmt clippy \
    && useradd --create-home --uid 10001 thistle \
    && install -d -o thistle -g thistle /workspace

ENV LIBCLANG_PATH=/usr/lib/llvm-18/lib \
    CARGO_NET_OFFLINE=true \
    BUNDLE_PATH=/home/thistle/bundle
WORKDIR /workspace
COPY --chown=thistle:thistle . .
USER thistle
RUN ruby -rjson -e 'abort "Docker Ruby differs from CI policy" unless RUBY_VERSION == JSON.parse(File.read(".github/ci-policy.json")).fetch("primary").fetch("ruby")' \
    && bundle install \
    && python3 -m venv /home/thistle/notes \
    && /home/thistle/notes/bin/pip install --require-hashes -r .github/requirements-notes.txt
ENV PATH=/home/thistle/notes/bin:/usr/local/cargo/bin:$PATH
CMD ["bundle", "exec", "rake", "test", "native", "map"]
