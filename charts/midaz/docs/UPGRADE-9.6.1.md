# Helm Upgrade from v9.6.0 to v9.6.1

## Topics

- **[Fixes](#fixes)**
  - [1. Application version bump to 4.2.1](#1-application-version-bump-to-421)
  - [2. Values formatting normalization](#2-values-formatting-normalization)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Application version bump to 4.2.1

The midaz application components have been updated from version `4.2.0` to `4.2.1`.

| Component | v9.6.0 | v9.6.1 |
|-----------|--------|--------|
| appVersion | 4.2.0 | 4.2.1 |
| ledger.image.tag | 4.2.0 | 4.2.1 |
| tracer.image.tag | 4.2.0 | 4.2.1 |

**Why this matters:**

This is a patch release that includes bug fixes and stability improvements. The upgrade will trigger rolling updates for both the ledger and tracer deployments due to the image tag changes.

**After (v9.6.1):**

```yaml
ledger:
  image:
    repository: lerianstudio/midaz-ledger
    pullPolicy: IfNotPresent
    tag: "4.2.1"

tracer:
  image:
    repository: lerianstudio/midaz-tracer
    pullPolicy: Always
    tag: "4.2.1"
```

> **Note:** The ledger and tracer services will be briefly unavailable during the rolling update as pods restart with the new image version.

#### Action required

No action is required unless you have pinned specific image tags in your values overrides. If you have explicitly set `ledger.image.tag` or `tracer.image.tag` to `4.2.0` or older versions, remove those overrides or update them to `4.2.1` to receive the latest fixes:

```yaml
ledger:
  image:
    tag: "4.2.1"

tracer:
  image:
    tag: "4.2.1"
```

### 2. Values formatting normalization

Two multi-line string values in the datastore configuration have been reformatted for consistency. This is a cosmetic change that does not affect functionality.

| Setting | Change |
|---------|--------|
| postgresql.auth.existingSecret | Line break added after opening quote |
| mongodb.auth.existingSecret | Line break added after opening quote |

**Before (v9.6.0):**

```yaml
postgresql:
  auth:
    existingSecret: '{{ if eq .Chart.Name "postgresql" }}{{ include "common.names.fullname" . }}{{ end }}'

mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
```

**After (v9.6.1):**

```yaml
postgresql:
  auth:
    existingSecret: '{{ if eq .Chart.Name "postgresql" }}{{ include "common.names.fullname"
      . }}{{ end }}'

mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname"
      . }}{{ end }}'
```

**Why this matters:**

This formatting change improves YAML readability and aligns with Helm's default rendering style. The template logic remains identical, so the rendered Secret names are unchanged.

**Operational impact:**

None. The PostgreSQL and MongoDB subchart configurations continue to reference the same Secret names as before. No pods will restart due to this change alone.

#### Action required

No action is required. If you have overridden `postgresql.auth.existingSecret` or `mongodb.auth.existingSecret` in your values file, your overrides will continue to work without modification.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.6.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.6.1 -n midaz
```
