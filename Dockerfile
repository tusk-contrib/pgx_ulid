# syntax=docker/dockerfile:1

ARG PG_MAJOR=18

# -------------------------------------------------------------------------------------- #
FROM ghcr.io/cloudnative-pg/postgresql:18.6-minimal-trixie AS builder

USER root

# pgx_ulid isn't published as a CNPG extension image -> upstream .deb
ARG PGX_ULID_VERSION=0.2.3
ARG TARGETARCH
ADD https://github.com/pksunkara/pgx_ulid/releases/download/v${PGX_ULID_VERSION}/pgx_ulid-v${PGX_ULID_VERSION}-pg18-${TARGETARCH}-linux-gnu.deb /tmp/pgx_ulid.deb
RUN apt-get update \
    && apt-get install -y --no-install-recommends /tmp/pgx_ulid.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/pgx_ulid.deb

# The .deb installs symlinks under /usr/{lib,share}/postgresql/18 pointing to the real
# files; dereference them into the CloudNativePG image volume layout.
RUN mkdir -p /out/lib /out/share/extension \
    && cp -L /usr/lib/postgresql/18/lib/pgx_ulid.so /out/lib/ \
    && cp -L /usr/share/postgresql/18/extension/ulid* /out/share/extension/ \
    && ls -lR /out

# -------------------------------------------------------------------------------------- #
# Extension-only image (CloudNativePG image volume layout)
FROM scratch AS final

COPY --from=builder /out/ /
