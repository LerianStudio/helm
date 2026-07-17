# Helm Upgrade from v8.4.0 to v8.5.0

## Topics

- **[Features](#features)**
  - [1. Application version bump to 3.7.8](#1-application-version-bump-to-378)
  - [2. CRM service image tag update](#2-crm-service-image-tag-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Application version bump to 3.7.8

The Midaz application version has been updated from `3.7.7` to `3.7.8`. This affects the ledger service container image tag.

#### Image tag changes

| Component | v8.4.0 | v8.5.0 |
|-----------|--------|--------|
| `ledger.image.tag` | `3.7.7` | `3.7.8` |
| Chart `appVersion` | `3.7.7` | `3.7.8` |

**Before (v8.4.0):**

```yaml
ledger:
  image:
    repository: lerianstudio/midaz-ledger
    pullPolicy: IfNotPresent
    tag: "3.7.7"
```

**After (v8.5.0):**

```yaml
ledger:
  image:
    repository: lerianstudio/midaz-ledger
    pullPolicy: IfNotPresent
    tag: "3.7.8"
```

> **Note:** For application-level changes and bug fixes included in version 3.7.8, refer to the [Midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

#### What this means for operators

The ledger service will pull and run the new `3.7.8` image during the upgrade. Kubernetes will perform a rolling update of the ledger deployment pods.

No configuration changes are required unless you have explicitly pinned the image tag in your values overrides. If you maintain a custom `values.yaml` with a hardcoded tag, update it to `3.7.8` or remove the override to use the chart default.

### 2. CRM service image tag update

The CRM service image tag has been updated from `3.7.6` to `3.7.8`, aligning it with the ledger service version.

#### Image tag changes

| Component | v8.4.0 | v8.5.0 |
|-----------|--------|--------|
| `crm.image.tag` | `3.7.6` | `3.7.8` |

**Before (v8.4.0):**

```yaml
crm:
  image:
    repository: lerianstudio/midaz-crm
    pullPolicy: Always
    tag: "3.7.6"
```

**After (v8.5.0):**

```yaml
crm:
  image:
    repository: lerianstudio/midaz-crm
    pullPolicy: Always
    tag: "3.7.8"
```

#### What this means for operators

The CRM service will be updated to version `3.7.8` during the upgrade. This brings the CRM component in sync with the ledger service version and includes any fixes or improvements from versions `3.7.7` and `3.7.8`.

Kubernetes will perform a rolling update of the CRM deployment pods. No manual intervention or configuration changes are required.

> **Important:** The CRM service uses `pullPolicy: Always`, which means the image will be pulled from the registry on every pod restart. Ensure your cluster has network access to the `lerianstudio/midaz-crm` repository.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.5.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 8.5.0 -n midaz
```
