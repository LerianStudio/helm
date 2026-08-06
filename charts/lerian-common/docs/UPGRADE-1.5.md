# Helm Upgrade from v1.4.0 to v1.5.0

## Topics ToC

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Object storage mask resolver (`objectStorage.value`)](#1-object-storage-mask-resolver-objectstoragevalue)
- **[Migration Steps](#migration-steps)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v1.5.0 adds two new **dependency mask resolvers**,
`lerian-common.objectStorage.value` and `lerian-common.kms.value`. This is a **minor, purely
additive release** — it introduces new helpers and changes nothing that existed in v1.4.0.

**What changed:**

- New helper `lerian-common.objectStorage.value` — a datastore-style mask for S3 / SeaweedFS
  connections, so an operator writes `objectStorage.<name>.bucket` instead of the app's native
  `OBJECT_STORAGE_<NAME>_BUCKET` env key.
- New helper `lerian-common.kms.value` — a datastore-style mask for the KMS / HashiCorp Vault
  connection, so an operator writes `kms.vaultAddr` instead of the native `KMS_VAULT_ADDR`. Single
  backend (no `<name>` sub-key); fields `vendor` / `vaultAddr` / `vaultAuthMethod` / `vaultRoleId` /
  `vaultMount`; the AppRole `KMS_VAULT_SECRET_ID` stays in the chart Secret (fail-fast when
  `vendor=hashicorp-vault`).

**Who is affected:**

- Nobody, on upgrade. No existing helper, value, or rendered output changes.
- Chart maintainers who want to adopt the mask for a chart's object-storage keys (opt-in).

**Backward compatibility:**

Fully backward-compatible. A chart that does not call the new helper renders identically to
v1.4.0. A chart that adopts it stays render-equivalent when no mask is set (the helper falls
through to the native key or the default).

## Features

### 1. Object storage mask resolver (`objectStorage.value`)

Object storage is a **dependency connection** (how the app reaches an S3/SeaweedFS backend), so it
now gets the same typed-mask treatment as datastores instead of being a raw passthrough env var.
The helper mirrors `lerian-common.datastore.value`, but is keyed by a backend **name** (an app may
reach several buckets — e.g. `ccs` / `fetcher` / `sta`) rather than a datastore **type**.

**Deploy modes and precedence** (identical to `datastore.value`):

| Mode | Path |
|------|------|
| SHARED | `global.objectStorage.<name>.<field>` (all products, one backend) |
| DEDICATED | `<product>.objectStorage.<name>.<field>` (this product's own backend) |

```
native configmap key  >  dedicated (<product>.objectStorage)  >  shared (global.objectStorage)  >  default
```

Presence-based per field (ordered `hasKey` checks, not chained `default`), so an explicit `false`
at any tier wins instead of falling through — e.g. `disableSSL: false` renders `"false"`, not the
default.

**Canonical fields:** `endpoint` · `region` · `bucket` · `disableSSL` · `usePathStyle`.

**Credentials are NOT masked here.** The access/secret keys (`*_ACCESS_KEY_ID`,
`*_SECRET_ACCESS_KEY`) go to the chart's own Secret (fail-fast when the backend is used), exactly
like datastore passwords — the mask covers only the non-secret connection fields.

**Usage** (in a component `configmap.yaml`, one line per field):

```yaml
OBJECT_STORAGE_CCS_BUCKET: {{ include "lerian-common.objectStorage.value" (dict
    "context" $ "configmap" .Values.brCcs.configmap
    "name" "ccs" "field" "bucket"
    "nativeKey" "OBJECT_STORAGE_CCS_BUCKET" "default" "lerian-ccs") | quote }}
```

**Operator mask** (shared, set once per environment):

```yaml
global:
  objectStorage:
    ccs:
      endpoint: "s3.amazonaws.com"
      region: "us-east-1"
      bucket: "my-ccs-bucket"
```

## Migration Steps

None required. To adopt the mask in a product chart:

1. Update the `lerian-common` dependency in your `Chart.yaml` to `1.5.0` and run
   `helm dependency update`.
2. Replace each object-storage passthrough (`OBJECT_STORAGE_<NAME>_<FIELD>: {{ $cm.KEY | default "…" }}`)
   with a `lerian-common.objectStorage.value` call, keeping the same `default` so the render stays
   byte-identical.
3. Move the operator-facing connection values into `global.objectStorage.<name>` (shared) or
   `<component>.objectStorage.<name>` (dedicated). Keep the credentials in the chart's Secret.
4. Verify with `helm template … --debug` that the rendered keys are unchanged when no mask is set.

## Command to upgrade

> **Note:** Since `lerian-common` is a library chart, you do **not** install or upgrade it directly.
> Update the dependency version in your product/umbrella chart's `Chart.yaml` to `1.5.0` and run
> `helm dependency update`, then upgrade the consuming chart.
