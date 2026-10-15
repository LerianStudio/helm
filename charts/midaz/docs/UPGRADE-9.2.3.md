# Helm Upgrade from v9.2.2 to v9.2.3

## Topics

- **[Application Version Update](#application-version-update)**
  - [1. Midaz application bump to 4.0.5](#1-midaz-application-bump-to-405)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Update

### 1. Midaz application bump to 4.0.5

This patch release updates the Midaz application from version `4.0.3` to `4.0.5`. The following components have been updated:

| Component | v9.2.2 | v9.2.3 |
|-----------|--------|--------|
| Chart version | 9.2.2 | 9.2.3 |
| App version | 4.0.3 | 4.0.5 |
| ledger.image.tag | 4.0.3 | 4.0.5 |
| tracer.image.tag | 4.0.3 | 4.0.5 |

#### What changed

The `ledger` and `tracer` services now use container images tagged `4.0.5`. This is a patch-level application update that includes bug fixes and minor improvements.

**Before (v9.2.2):**

```yaml
ledger:
  image:
    tag: "4.0.3"

tracer:
  image:
    tag: "4.0.3"
```

**After (v9.2.3):**

```yaml
ledger:
  image:
    tag: "4.0.5"

tracer:
  image:
    tag: "4.0.5"
```

#### Why it matters

This update ensures you're running the latest stable patch release of the Midaz application with the most recent bug fixes and stability improvements. As a patch-level bump, no configuration changes or data migrations are required.

#### Operational impact

- The `ledger` and `tracer` pods will be recreated during the upgrade to pull the new image tags
- Expect a brief service interruption during pod rollout (typically 30-60 seconds depending on your readiness probe configuration)
- No database migrations or configuration changes are required for this update

> **Note:** For detailed application-level changes between 4.0.3 and 4.0.5, refer to the [Midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.3 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.3 -n midaz
```
