# Helm Upgrade from v5.3.0 to v5.3.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [Application version promotion from beta to stable](#application-version-promotion-from-beta-to-stable)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that promotes the application version from `1.14.0-beta.6` to the stable `1.14.0` release across all five service components. The chart version increments from `5.3.0` to `5.3.1`. No configuration values are added, removed, or renamed, so existing custom values files remain fully compatible.

In the `1.14.0` image, error `PIX-0501` (CRM Authentication Error) returns HTTP 502 instead of HTTP 403. The error code does not change.

The expected upgrade path is an in-place Helm upgrade that will trigger a rolling restart of all component deployments due to the image tag change.

## Fixes

### Application version promotion from beta to stable

The application image tag has been updated from `1.14.0-beta.6` to `1.14.0` for all service components, marking the transition from beta to stable release.

**What changed:**

All five service components now reference the stable `1.14.0` image tag instead of the beta version:

| Component | v5.3.0 | v5.3.1 |
|-----------|--------|--------|
| Chart version | `5.3.0` | `5.3.1` |
| App version | `1.14.0-beta.6` | `1.14.0` |
| `pix.image.tag` | `1.14.0-beta.6` | `1.14.0` |
| `inbound.image.tag` | `1.14.0-beta.6` | `1.14.0` |
| `outbound.image.tag` | `1.14.0-beta.6` | `1.14.0` |
| `reconciliation.image.tag` | `1.14.0-beta.6` | `1.14.0` |
| `schedule.image.tag` | `1.14.0-beta.6` | `1.14.0` |

**Operational impact:**

The image tag change will trigger a rolling restart of all five deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`).

> **Note:** If you have explicitly overridden any `image.tag` values in your custom values file, those overrides will continue to take precedence. Review your custom values to ensure you want to adopt the stable `1.14.0` release.

**Example configuration (v5.3.1 defaults):**

```yaml
pix:
  image:
    tag: "1.14.0"

inbound:
  image:
    tag: "1.14.0"

outbound:
  image:
    tag: "1.14.0"

reconciliation:
  image:
    tag: "1.14.0"

schedule:
  image:
    tag: "1.14.0"
```

## Configuration Changes

No configuration values are added, removed, or renamed in this release. The only change is the default image tag for all service components.

| Setting | v5.3.0 | v5.3.1 |
|---------|--------|--------|
| Chart version | `5.3.0` | `5.3.1` |
| App version | `1.14.0-beta.6` | `1.14.0` |
| All `*.image.tag` defaults | `1.14.0-beta.6` | `1.14.0` |

## Migration Steps

This upgrade requires no manual migration steps or configuration changes. The image tag update is handled automatically by Helm.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Verify your custom values file does not pin image tags to the beta version. If you have explicit overrides, decide whether to remove them to adopt the stable release or keep them:

```bash
grep -E "tag.*1.14.0-beta" your-custom-values.yaml
```

3. Run the upgrade command.

4. Monitor the rollout status for all deployments:

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

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.1 -n midaz-plugins
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 5.3.1 -n midaz-plugins
```
