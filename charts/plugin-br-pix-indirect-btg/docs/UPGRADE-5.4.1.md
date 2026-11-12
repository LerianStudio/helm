# Helm Upgrade from v5.4.0 to v5.4.1

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `1.14.0` to `1.14.1` across all five service components: `pix`, `inbound`, `outbound`, `reconciliation`, and `schedule`. No configuration schema changes are introduced — all existing values remain compatible.

The expected upgrade path is a standard in-place Helm upgrade that will trigger a rolling restart of all five deployments.

## Application Version Update

The chart bumps the container image tag for all services from `1.14.0` to `1.14.1`. This update applies uniformly across the entire plugin stack.

| Component | v5.4.0 image tag | v5.4.1 image tag |
|-----------|------------------|------------------|
| `pix` | `1.14.0` | `1.14.1` |
| `inbound` | `1.14.0` | `1.14.1` |
| `outbound` | `1.14.0` | `1.14.1` |
| `reconciliation` | `1.14.0` | `1.14.1` |
| `schedule` | `1.14.0` | `1.14.1` |

**What changed:**

The following values have been updated in `values.yaml`:

| Setting | v5.4.0 | v5.4.1 |
|---------|--------|--------|
| Chart version | `5.4.0` | `5.4.1` |
| App version | `1.14.0` | `1.14.1` |
| `pix.image.tag` | `"1.14.0"` | `"1.14.1"` |
| `inbound.image.tag` | `"1.14.0"` | `"1.14.1"` |
| `outbound.image.tag` | `"1.14.0"` | `"1.14.1"` |
| `reconciliation.image.tag` | `"1.14.0"` | `"1.14.1"` |
| `schedule.image.tag` | `"1.14.0"` | `"1.14.1"` |

**Why it matters:**

This patch release delivers bug fixes, performance improvements, or minor feature enhancements included in application version `1.14.1`. Consult the application release notes for `1.14.1` to understand the specific changes in the container image.

**Operational impact:**

The upgrade will trigger a rolling restart of all five deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) because the container image tag changes. Depending on your replica count and rolling update strategy, expect brief traffic shifts during the rollout.

> **Note:** If you have pinned image tags in your custom values file, ensure you update them to `1.14.1` or remove the override to inherit the chart default.

## Configuration Changes

No values are added, removed, or renamed in this release. All existing custom values files remain fully compatible.

If you have overridden `image.tag` for any component in your values file, you may choose to:

- Remove the override to inherit the new chart default (`1.14.1`)
- Update your override to explicitly pin `1.14.1`

**Example override (if you want to keep explicit control):**

```yaml
pix:
  image:
    tag: "1.14.1"

inbound:
  image:
    tag: "1.14.1"

outbound:
  image:
    tag: "1.14.1"

reconciliation:
  image:
    tag: "1.14.1"

schedule:
  image:
    tag: "1.14.1"
```

## Migration Steps

This upgrade requires no manual migration steps. The image tag change is handled automatically by Helm during the upgrade.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Verify that your environment can pull the `1.14.1` image from the configured registry.

3. Run the upgrade command during a maintenance window or when rolling restarts are acceptable.

4. Monitor the rollout status for all five deployments:

```bash
kubectl rollout status deployment -n midaz-plugins -l app.kubernetes.io/instance=plugin-br-pix-indirect-btg
```

5. Verify all pods are running the new image version:

```bash
kubectl get pods -n midaz-plugins -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

6. Check service logs for any startup issues or errors:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
```

> **Important:** If any deployment fails to roll out successfully, you can roll back to the previous chart version using: `helm rollback plugin-br-pix-indirect-btg -n midaz-plugins`

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.4.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.4.1
```
