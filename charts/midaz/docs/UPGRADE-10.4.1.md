# Helm Upgrade from v10.4.0 to v10.4.1

## Topics

- **[Application Version Update](#application-version-update)**
  - [1. Midaz application version bump to 4.4.1](#1-midaz-application-version-bump-to-441)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Update

### 1. Midaz application version bump to 4.4.1

This release updates the Midaz application from version 4.4.0 to 4.4.1 across all components. This is a patch-level application update that includes bug fixes and minor improvements to the ledger, tracer, and migration runner images.

#### What changed

| Component | v10.4.0 | v10.4.1 |
|-----------|---------|---------|
| Chart version | 10.4.0 | 10.4.1 |
| Application version | 4.4.0 | 4.4.1 |
| `ledger.image.tag` | 4.4.0 | 4.4.1 |
| `tracer.image.tag` | 4.4.0 | 4.4.1 |
| `midaz-ledger-migrations.image.tag` | 4.4.0 | 4.4.1 |
| `midaz-tracer-migrations.image.tag` | 4.4.0 | 4.4.1 |

**Before (v10.4.0):**

```yaml
ledger:
  image:
    tag: "4.4.0"

tracer:
  image:
    tag: "4.4.0"

midaz-ledger-migrations:
  image:
    tag: 4.4.0

midaz-tracer-migrations:
  image:
    tag: 4.4.0
```

**After (v10.4.1):**

```yaml
ledger:
  image:
    tag: "4.4.1"

tracer:
  image:
    tag: "4.4.1"

midaz-ledger-migrations:
  image:
    tag: 4.4.1

midaz-tracer-migrations:
  image:
    tag: 4.4.1
```

#### Operational impact

- All ledger and tracer pods will be restarted during the upgrade to pull the new 4.4.1 images
- Migration runners will use the 4.4.1 image for any new migration jobs
- No configuration changes are required — the upgrade is automatic when you apply the new chart version
- No database schema changes are included in this patch release

> **Note:** This is a patch-level application update. The 4.4.x series maintains the same probe configuration, health check ports, and deployment behavior introduced in 4.4.0. Tags from 4.5.0-beta.94 onward introduce the health preset (HEALTH_PORT 8099, preset probes, PDB, and rollout strategy), but 4.4.1 retains the 4.4.0 probe and port configuration.

#### Action required

No action required. The image tag update is applied automatically during the Helm upgrade. The chart will pull the new 4.4.1 images and perform a rolling restart of the ledger and tracer deployments.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.4.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.4.1
```
