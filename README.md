# pgx_ulid for CloudNativePG

A container image that packages the [`pgx_ulid`](https://github.com/pksunkara/pgx_ulid) PostgreSQL extension for use with [CloudNativePG](https://cloudnative-pg.io/) **image volume extensions**.

The image contains only the extension files (no OS, no PostgreSQL). CloudNativePG mounts it into the Postgres pods as a read-only image volume, so you can add `pgx_ulid` to a cluster without building a custom PostgreSQL operand image.

## What's inside

| Component        | Version                                          |
| ---------------- | ------------------------------------------------ |
| PostgreSQL       | 18 (built against `ghcr.io/cloudnative-pg/postgresql:18.6-minimal-trixie`) |
| pgx_ulid         | `v0.2.3` (configurable via `ULID_VERSION`)       |
| cargo-pgrx       | Matches the `pgrx` version pinned in pgx_ulid's `Cargo.toml` |

Image layout, which follows the CloudNativePG extension image convention:

```
/
├── lib/
│   └── pgx_ulid.so
└── share/
    └── extension/
        ├── pgx_ulid.control
        └── pgx_ulid--*.sql
```

## Requirements

- CloudNativePG 1.27 or later (image volume extension support)
- PostgreSQL 18 operand image
- Kubernetes 1.33 or later with the `ImageVolume` feature enabled

## Building

```sh
docker build -t ghcr.io/tusk-contrib/pgx_ulid:v0.2.3-18.6-minimal-trixie .
docker push ghcr.io/tusk-contrib/pgx_ulid:v0.2.3-18.6-minimal-trixie
```

To build a different upstream release, override the tag:

```sh
docker build --build-arg ULID_VERSION=v0.2.3 -t ghcr.io/tusk-contrib/pgx_ulid:v0.2.3-18.6-minimal-trixie .
```

The build has two stages:

1. **builder**: starts from the CloudNativePG PostgreSQL 18 image, installs the Rust toolchain and the PostgreSQL server headers, clones pgx_ulid at `ULID_VERSION`, installs the matching `cargo-pgrx` version, and runs `cargo pgrx install --release`.
2. **final**: a `scratch` image that holds only the compiled `.so`, the `.control` file, and the SQL scripts.

> The PostgreSQL major version (18) is hardcoded in the Dockerfile. To target another major version, change the base image tag, the `postgresql-server-dev-*` package, and the `/usr/lib/postgresql/<major>` and `/usr/share/postgresql/<major>` paths.

## Usage with CloudNativePG

Add the extension image to your `Cluster`:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-ulid
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:18-minimal-trixie
  instances: 1
  storage:
    size: 1Gi
  postgresql:
    extensions:
      - name: pgx_ulid
        image:
          reference: ghcr.io/tusk-contrib/pgx_ulid:v0.2.3-18.6-minimal-trixie
```

Then create the extension in a database, either declaratively with a `Database` resource:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: cluster-ulid-app
spec:
  name: app
  owner: app
  cluster:
    name: cluster-ulid
  extensions:
    - name: pgx_ulid
```

or manually with SQL:

```sql
CREATE EXTENSION pgx_ulid;
```

## Example

```sql
SELECT gen_ulid();

CREATE TABLE users (
  id   ulid NOT NULL DEFAULT gen_ulid() PRIMARY KEY,
  name text NOT NULL
);
```

See the [upstream pgx_ulid documentation](https://github.com/pksunkara/pgx_ulid) for all functions, casts, and operators.

## Credits

- [pgx_ulid](https://github.com/pksunkara/pgx_ulid) by Pavan Kumar Sunkara
- [CloudNativePG](https://cloudnative-pg.io/)
