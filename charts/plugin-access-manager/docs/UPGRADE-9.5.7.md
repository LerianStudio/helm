# Helm Upgrade from v9.5.6 to v9.5.7

# Topics

- **[Fixes](#fixes)**
  - [1. PostgreSQL Image Digest Pinning](#1-postgresql-image-digest-pinning)
  - [2. Valkey Image Digest Pinning](#2-valkey-image-digest-pinning)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. PostgreSQL Image Digest Pinning

The `auth-database` PostgreSQL image now includes a pinned digest to ensure consistent deployments and prevent unexpected version changes.

**What changed:**

| Setting | v9.5.6 | v9.5.7 |
|---------|--------|--------|
| `auth-database.image.digest` | *(not set)* | `sha256:7045d816bdf7e704f0f662fabf243f3c0a975aa380e73e4e881ee94740f60d4f` |
| PostgreSQL version | latest (floating) | latest (PostgreSQL 18.6.0, pinned) |

**Why this matters:**

PostgreSQL refuses to start with a data directory created by a different major version. By pinning the image digest, this release ensures that:

- The PostgreSQL version only changes when you explicitly upgrade the chart
- Accidental image pulls of newer major versions won't cause data directory incompatibility errors
- Your database pods won't fail to start due to version mismatches after image cache refreshes

**Configuration:**

The new digest is automatically applied when you upgrade. The values.yaml now includes:

```yaml
auth-database:
  image:
    repository: bitnamisecure/postgresql
    tag: "latest"
    # latest (PostgreSQL 18.6.0), pinned: PostgreSQL refuses a data directory of another major.
    digest: "sha256:7045d816bdf7e704f0f662fabf243f3c0a975aa380e73e4e881ee94740f60d4f"
```

> **Action required if you override the image:** When a digest is set, the Bitnami image helper renders `<registry>/<repository>@<digest>` and **ignores `tag`**. If your values override `auth-database.image.repository`, `auth-database.image.tag`, `auth-database.image.registry` or `global.imageRegistry` (for example a private mirror, or `bitnamilegacy/postgresql:17.6.0` to stay on PostgreSQL 17), v9.5.7 renders your repository with the chart's digest, for example `docker.io/bitnamilegacy/postgresql@sha256:7045d816...`. That digest does not exist in another repository or in a re-pushed mirror, so the database pod fails with `ImagePullBackOff`. The single-replica StatefulSet replaces its only pod, so the identity database and login stay down until you fix it. Clear the digest together with your override:

```yaml
auth-database:
  image:
    repository: bitnamilegacy/postgresql   # your override
    tag: "17.6.0"                          # your override
    digest: ""                             # required: otherwise the chart digest wins over the tag
```

> **Note:** The pinned digest is PostgreSQL **18.6.0**. PostgreSQL refuses a data directory written by another major version. An install whose data was created by PostgreSQL 18 (every install that has run the chart's `latest` default since v5.2.0) opens it unchanged. A data directory created by PostgreSQL 17 is **not** compatible: that install must stay on its own major using an override with `digest: ""`, as shown above.

> **Note:** The image reference changes, so upgrading restarts the `auth-database` StatefulSet pod once. It runs a single replica by default, so expect a short identity-database outage (and failed logins) while the pod restarts. Plan a maintenance window.

### 2. Valkey Image Digest Pinning

The `valkey` image now includes a pinned digest to ensure the version only changes during explicit chart upgrades.

**What changed:**

| Setting | v9.5.6 | v9.5.7 |
|---------|--------|--------|
| `valkey.image.digest` | *(not set)* | `sha256:26e25932c8e8026708cff3360032efc1978588da5ea680e151b3315913a3a38d` |
| Valkey version | latest (floating) | latest (Valkey 9.1.2, pinned) |

**Why this matters:**

Similar to PostgreSQL, pinning the Valkey image digest prevents unexpected version changes that could affect your cache layer:

- Ensures consistent Valkey behavior across pod restarts and node migrations
- Prevents automatic upgrades to new Valkey versions that might introduce breaking changes
- The version opening a persistent volume only changes when you intentionally upgrade the chart

**Configuration:**

The new digest is automatically applied when you upgrade. The values.yaml now includes:

```yaml
valkey:
  image:
    repository: bitnamisecure/valkey
    tag: "latest"
    # latest (Valkey 9.1.2), pinned so the version opening this volume changes only on upgrade.
    digest: "sha256:26e25932c8e8026708cff3360032efc1978588da5ea680e151b3315913a3a38d"
```

> **Action required if you override the image:** As with PostgreSQL, the digest replaces the tag. If your values override `valkey.image.repository`, `valkey.image.tag`, `valkey.image.registry` or `global.imageRegistry`, v9.5.7 renders your repository with the chart's digest (for example `myregistry.example.com/mirror/valkey@sha256:26e25932...`). The pull fails unless that exact digest exists there. Clear the digest together with your override:

```yaml
valkey:
  image:
    repository: mirror/valkey   # your override
    tag: "<your-tag>"           # your override
    digest: ""                  # required: otherwise the chart digest wins over the tag
```

> **Note:** The image reference changes, so upgrading restarts the Valkey StatefulSet pod once. Data kept on its volume is read by the pinned Valkey 9.1.2. Do not point an existing volume at an older Valkey major: an older server may not read data written by a newer one.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.7 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.7 -n plugin-access-manager
```
