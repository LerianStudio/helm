# Helm Upgrade from v10.0.3 to v10.0.4

## Topics

- **[Application Version Update](#application-version-update)**
  - [1. Midaz Application Version Bump to 4.4.0](#1-midaz-application-version-bump-to-440)

## Application Version Update

### 1. Midaz Application Version Bump to 4.4.0

This release updates the Midaz application from version 4.3.0 to 4.4.0 across all components. This is a patch-level chart update that bumps the underlying application images.

#### What Changed

The following image tags have been updated in `values.yaml`:

| Component | v10.0.3 | v10.0.4 |
|-----------|---------|---------|
| `ledger.image.tag` | `4.3.0` | `4.4.0` |
| `tracer.image.tag` | `4.3.0` | `4.4.0` |
| `midaz-ledger-migrations.image.tag` | `4.3.0` | `4.4.0` |
| `midaz-tracer-migrations.image.tag` | `4.3.0` | `4.4.0` |

**Before (v10.0.3):**

```yaml
ledger:
  image:
    tag: "4.3.0"

tracer:
  image:
    tag: "4.3.0"

midaz-ledger-migrations:
  image:
    tag: 4.3.0

midaz-tracer-migrations:
  image:
    tag: 4.3.0
```

**After (v10.0.4):**

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

#### Why This Matters

- **Application Updates**: The Midaz application version 4.4.0 includes bug fixes, performance improvements, or new features from the upstream project
- **Migration Compatibility**: Both the ledger and tracer migration runners are updated to ensure schema changes are compatible with the new application versions
- **Consistency**: All Midaz components are kept in sync at the same application version

#### Operator Impact

This is a standard application version update. The upgrade process will:

1. Run the `midaz-ledger-migrations` job (if enabled) to apply any new database migrations for the ledger
2. Run the `midaz-tracer-migrations` job (if enabled) to apply any new database migrations for the tracer
3. Roll out new pods for the `midaz-ledger` deployment with the 4.4.0 image
4. Roll out new pods for the `midaz-tracer` deployment with the 4.4.0 image

> **Note:** If you have overridden image tags in your `values.yaml` to pin to a specific version, those overrides will take precedence. Review your custom values to ensure they are compatible with chart version 10.0.4.

> **Important:** The migration jobs run as Helm hooks during the upgrade. Monitor their completion before the main application pods start:

```bash
kubectl get jobs -n midaz -l app.kubernetes.io/component=migrations
kubectl logs -n midaz -l app.kubernetes.io/component=migrations --tail=100 -f
```

> **Note:** If your deployment uses custom image repositories (via `ledger.image.repository` or `tracer.image.repository`), ensure that version 4.4.0 is available in those repositories before upgrading.

#### Action Required

No action is required for standard deployments. The upgrade will automatically pull and deploy the new image versions.

**If you have pinned image tags in your values:**

1. Review your custom `values.yaml` for any image tag overrides:

```yaml
ledger:
  image:
    tag: "4.3.0"  # Custom override
```

2. Update them to 4.4.0 or remove the override to use the chart default:

```yaml
ledger:
  image:
    tag: "4.4.0"
```

3. Proceed with the upgrade

**If you use a private image registry:**

1. Ensure the following images are available in your registry:
   - `midaz-ledger:4.4.0`
   - `midaz-tracer:4.4.0`
   - `midaz-ledger-migrations:4.4.0`
   - `midaz-tracer-migrations:4.4.0`

2. Verify your `imagePullSecrets` are configured correctly in `values.yaml`

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.4 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.4 -n midaz
```
