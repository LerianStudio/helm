# Helm Upgrade from v11.2.0 to v11.2.1

## Topics

- **[Fixes](#fixes)**
  - [1. Application version bump to 4.5.1](#1-application-version-bump-to-451)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Application version bump to 4.5.1

This release updates the Midaz application images from `4.5.0` to `4.5.1` for the `ledger`, `tracer`, and their migration runners. The chart version increments from `11.2.0` to `11.2.1`. No configuration changes, template modifications, or new features are included.

#### What changed

| Setting | v11.2.0 | v11.2.1 |
|---------|---------|---------|
| `appVersion` | `4.5.0` | `4.5.1` |
| `ledger.image.tag` | `4.5.0` | `4.5.1` |
| `tracer.image.tag` | `4.5.0` | `4.5.1` |
| `midaz-ledger-migrations.image.tag` | `4.5.0` | `4.5.1` |
| `midaz-tracer-migrations.image.tag` | `4.5.0` | `4.5.1` |

The `crm` service image tag is not changed in this release.

#### Operational impact

- The `ledger` and `tracer` deployments roll once to pick up the new image tags.
- The chart version is part of the `helm.sh/chart` label in the pod templates, so the chart version bump from `11.2.0` to `11.2.1` triggers a rolling restart of all Midaz pods, even those whose image tags did not change.
- The ledger migrations Job runs as a `pre-upgrade` hook on every upgrade, including this one, using the `4.5.1` migration image.
- The tracer migrations Job runs as a `pre-upgrade` hook on every upgrade, including this one, using the `4.5.1` migration image.
- No configuration changes are required. The upgrade applies the new image tags automatically.

#### Action required

No action required. The upgrade applies the new image tags using the existing configuration.

#### Verification after upgrade

Check that the new image tags are running:

```bash
kubectl get deployment -n midaz midaz-ledger -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get deployment -n midaz midaz-tracer -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Both commands should return images tagged with `4.5.1`.

Check that the migration Jobs completed successfully:

```bash
kubectl get job -n midaz -l app.kubernetes.io/name=midaz-ledger-migrations
kubectl get job -n midaz -l app.kubernetes.io/name=midaz-tracer-migrations
```

Both Jobs should show `1/1` completions.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.2.1
```
