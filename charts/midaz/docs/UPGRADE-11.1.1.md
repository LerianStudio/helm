# Helm Upgrade from v11.1.0 to v11.1.1

## Topics

- **[Fixes](#fixes)**
  - [1. Application version bump to 4.4.3](#1-application-version-bump-to-443)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Application version bump to 4.4.3

This release updates the Midaz application images from `4.4.2` to `4.4.3` for the `ledger`, `tracer`, and their respective migration runners. The chart version increments from `11.1.0` to `11.1.1`. No configuration schema, template logic, or default values change beyond the image tags.

#### What changed

| Setting | v11.1.0 | v11.1.1 |
|---------|---------|---------|
| `appVersion` | `4.4.2` | `4.4.3` |
| `ledger.image.tag` | `4.4.2` | `4.4.3` |
| `tracer.image.tag` | `4.4.2` | `4.4.3` |
| `midaz-ledger-migrations.image.tag` | `4.4.2` | `4.4.3` |
| `midaz-tracer-migrations.image.tag` | `4.4.2` | `4.4.3` |

The `4.4.3` application version is a patch release that includes bug fixes and stability improvements. No new features, environment variables, or configuration flags are introduced.

#### Operational impact

- **Image pull**: Kubernetes pulls the `4.4.3` images for `midaz-ledger`, `midaz-tracer`, `midaz-ledger-migrations`, and `midaz-tracer-migrations` containers. Ensure your cluster has network access to the image registry and sufficient pull quota.
- **Rolling restart**: The chart version is part of the `helm.sh/chart` label in the pod templates. All `ledger` and `tracer` pods roll once to pick up the new image tag and chart label.
- **Migration Jobs**: The `midaz-ledger-migrations` Job runs as a `pre-upgrade` hook on every upgrade, including this one. The `midaz-tracer-migrations` Job also runs if `tracer.enabled` is `true`. Both Jobs use the `4.4.3` migration image.
- **Downtime**: Rolling updates proceed according to your `strategy`, `maxUnavailable`, and `maxSurge` settings. The default `RollingUpdate` strategy ensures at least one replica remains available during the upgrade if `replicaCount` is greater than 1.
- **Compatibility**: The `4.4.3` application version is backward-compatible with the database schema applied by `4.4.2` migrations. No schema changes are introduced in this patch release.

#### Action required

No action required. The upgrade applies automatically when you run `helm upgrade`.

#### Verification after upgrade

Check that the new image tags are running:

```bash
kubectl get deployment -n midaz -l app.kubernetes.io/name=midaz-ledger -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
kubectl get deployment -n midaz -l app.kubernetes.io/name=midaz-tracer -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
```

Both commands should return an image reference ending in `:4.4.3`.

Verify that the migration Jobs completed successfully:

```bash
kubectl get job -n midaz -l app.kubernetes.io/name=midaz-ledger-migrations -o jsonpath='{.items[0].status.succeeded}'
kubectl get job -n midaz -l app.kubernetes.io/name=midaz-tracer-migrations -o jsonpath='{.items[0].status.succeeded}'
```

Each command should return `1` if the Job succeeded. The `tracer-migrations` command returns a result only when `tracer.enabled` is `true`.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.1.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.1.1
```
