# Helm Upgrade from v9.1.0 to v9.1.1

## Topics

- **[Fixes](#fixes)**
  - [1. Application version bump to 4.0.2](#1-application-version-bump-to-402)
  - [2. Tracer secrets formatting correction](#2-tracer-secrets-formatting-correction)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Application version bump to 4.0.2

The midaz application components have been updated from version 3.8.4 to 4.0.2. This patch release includes bug fixes and stability improvements.

#### Component image tag updates

| Component | v9.1.0 | v9.1.1 |
|-----------|--------|--------|
| Chart appVersion | 3.8.4 | 4.0.2 |
| ledger.image.tag | 4.0.0 | 4.0.2 |
| tracer.image.tag | 4.0.0 | 4.0.2 |

The following components now use the updated image tags:

**Ledger service:**
```yaml
ledger:
  image:
    tag: "4.0.2"
```

**Tracer service:**
```yaml
tracer:
  image:
    tag: "4.0.2"
```

> **Note:** This is a patch-level application update. No configuration changes or data migrations are required. The upgrade will perform a rolling update of the affected deployments.

For detailed application-level changes, refer to the [midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

### 2. Tracer secrets formatting correction

A minor formatting issue in the tracer secrets template has been corrected. The comment for `existingSecrets` was incorrectly indented in the previous version.

**Before (v9.1.0):**
```yaml
tracer:
  secrets:
    # MULTI_TENANT_SERVICE_API_KEY: ""
    # MULTI_TENANT_REDIS_PASSWORD: ""
  # -- Existing secrets name
    SD_TOKEN: ""
```

**After (v9.1.1):**
```yaml
tracer:
  secrets:
    # MULTI_TENANT_SERVICE_API_KEY: ""
    # MULTI_TENANT_REDIS_PASSWORD: ""

    # -- Existing secrets name
    SD_TOKEN: ""
```

This change corrects the YAML structure and improves readability. It has no operational impact — the secret values and behavior remain unchanged.

> **Note:** No action is required from operators. This is a documentation/formatting fix only.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.1.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.1.1 -n midaz
```
