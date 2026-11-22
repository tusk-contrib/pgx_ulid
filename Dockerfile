# syntax=docker/dockerfile:1

ARG PG_MAJOR=18
ARG ULID_VERSION=v0.2.3

# -------------------------------------------------------------------------------------- #
FROM ghcr.io/cloudnative-pg/postgresql:18.6-minimal-trixie AS builder

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git pkg-config libssl-dev \
        clang libclang-dev postgresql-server-dev-18 \
    && rm -rf /var/lib/apt/lists/*

ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:$PATH

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal

WORKDIR /src
ARG ULID_VERSION
RUN git clone --branch "${ULID_VERSION}" --depth 1 \
    https://github.com/pksunkara/pgx_ulid.git .

# cargo-pgrx must match the pgrx version pinned in Cargo.toml
RUN PGRX_VERSION="$(grep -E '^pgrx\s*=' Cargo.toml | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" \
    && echo "pgrx ${PGRX_VERSION}" \
    && cargo install cargo-pgrx --version "=${PGRX_VERSION}" --locked

ENV PG_CONFIG=/usr/lib/postgresql/18/bin/pg_config

RUN cargo pgrx init --pg18="${PG_CONFIG}"

RUN cargo pgrx install --release \
        --no-default-features --features pg18 \
        --pg-config "${PG_CONFIG}" \
    && ls -l /usr/share/postgresql/18/extension/ | grep -i ulid \
    && ls -l /usr/lib/postgresql/18/lib/ | grep -i ulid

# -------------------------------------------------------------------------------------- #
# Extension-only image (CloudNativePG image volume layout)
FROM scratch AS final

COPY --from=builder /usr/share/postgresql/18/extension/pgx_ulid* /share/extension/
COPY --from=builder /usr/lib/postgresql/18/lib/pgx_ulid.so /lib/
