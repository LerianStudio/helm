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

> **Important:** If you have overridden the `auth-database.image.repository` or `auth-database.image.tag` in your values, the digest pinning will still apply. To use a different PostgreSQL version, you must explicitly override the digest as well:

```yaml
auth-database:
  image:
    repository: bitnamisecure/postgresql
    tag: "16.0.0"
    digest: "sha256:your-custom-digest-here"
```

> **Note:** This change does not affect existing persistent volumes. Your data remains intact and compatible with PostgreSQL 18.6.0.

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

> **Important:** If you have overridden the `valkey.image.repository` or `valkey.image.tag` in your values, the digest pinning will still apply. To use a different Valkey version, you must explicitly override the digest as well:

```yaml
valkey:
  image:
    repository: bitnamisecure/valkey
    tag: "8.0.0"
    digest: "sha256:your-custom-digest-here"
```

> **Note:** This change does not affect existing Valkey data. Your cache data remains intact and compatible with Valkey 9.1.2.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.7 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.7 -n plugin-access-manager
```
