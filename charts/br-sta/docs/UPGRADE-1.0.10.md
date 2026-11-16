# Helm Upgrade from v1.0.9 to v1.0.10

This is a patch release that updates the application version from 1.4.1 to 1.4.2 across all components. The upgrade includes new container images for the manager, worker, migrations, and mock-sta components.

## Application version update

The chart's `appVersion` has been updated from `1.4.1` to `1.4.2`, which affects all four components of the br-sta application.

### Image tag changes

All component image tags have been updated to version 1.4.2:

| Component | v1.0.9 | v1.0.10 |
|-----------|--------|---------|
| manager.image.tag | 1.4.1 | 1.4.2 |
| worker.image.tag | 1.4.1 | 1.4.2 |
| migrations.image.tag | 1.4.1 | 1.4.2 |
| mockSta.image.tag | 1.4.1 | 1.4.2 |

### What this means for operators

- All pods (manager, worker, migrations job, and mock-sta if enabled) will be recreated with the new image version
- The manager and worker deployments will perform a rolling update
- If you have overridden any image tags in your values, those overrides will remain in effect unless you explicitly update them

> **Note:** If you have pinned specific image tags in your custom values.yaml, review whether you want to adopt the new 1.4.2 version or continue using your pinned versions.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.10
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.10
```
