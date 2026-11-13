# Helm Upgrade from v10.4.0 to v10.4.1

## Topics

- **[Application Version Update](#application-version-update)**
  - [1. Midaz application version bump to 4.4.1](#1-midaz-application-version-bump-to-441)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Update

### 1. Midaz application version bump to 4.4.1

This release updates the Midaz application from version 4.4.0 to 4.4.1 for the ledger, enabled tracer, and their migration runners (legacy CRM is unchanged). This is a patch-level application update that includes bug fixes and minor improvements to the ledger, tracer, and migration runner images.

#### What changed

| Component | v10.4.0 | v10.4.1 |
|-----------|---------|---------|
| Chart version | 10.4.0 | 10.4.1 |
| Application version | 4.4.0 | 4.4.1 |
| `ledger.image.tag` | 4.4.0 | 4.4.1 |
| `tracer.image.tag` | 4.4.0 | 4.4.1 |
| Ledger migration image (default) | 4.4.0 | 4.4.1 |
| Tracer migration image (default, if enabled) | 4.4.0 | 4.4.1 |

The effective migration overrides are `ledger.migrations.image.tag` and `tracer.migrations.image.tag`. When empty, each follows its component's `image.tag`; an explicit migration pin takes precedence. The similarly named root `midaz-ledger-migrations` and `midaz-tracer-migrations` blocks in the shipped values file are not consumed by these templates.

**Before (v10.4.0):**

```yaml
ledger:
  image:
    tag: "4.4.0"
  migrations:
    image:
      tag: "4.4.0"

tracer:
  image:
    tag: "4.4.0"
  migrations:
    image:
      tag: "4.4.0"

```

**After (v10.4.1):**

```yaml
ledger:
  image:
    tag: "4.4.1"
  migrations:
    image:
      tag: "4.4.1"

tracer:
  image:
    tag: "4.4.1"
  migrations:
    image:
      tag: "4.4.1"

```

#### Operational impact

- All ledger and tracer pods will be restarted during the upgrade to pull the new 4.4.1 images
- Migration runners will use the 4.4.1 image for any new migration jobs
- No configuration changes are required — the upgrade is automatic when you apply the new chart version
- No database schema changes are included in this patch release

> **Note:** This is a patch-level application update. The 4.4.x series maintains the same probe configuration, health check ports, and deployment behavior introduced in 4.4.0. Tags from 4.5.0-beta.94 onward introduce the health preset (HEALTH_PORT 8099, preset probes, PDB, and rollout strategy), but 4.4.1 retains the 4.4.0 probe and port configuration.

#### Action required

With default image settings, the update is applied during Helm upgrade. Explicit component or migration image pins remain in force: review and update them together if you intend to move to 4.4.1. Tracer effects apply only when enabled. Apply any edited, complete values file explicitly with `-f` to both preview and upgrade commands.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.4.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.4.1
```
