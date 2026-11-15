# Helm Upgrade from v1.0.8 to v1.0.9

This is a patch release that updates the application version from 1.4.0 to 1.4.1 across all components. The upgrade includes updated container images for the manager, worker, migrations job, and mock-sta server.

## Application Version Update

The `appVersion` has been bumped from `1.4.0` to `1.4.1`, which updates the default image tags for all br-sta components.

### Updated Components

All four components now use version `1.4.1`:

| Component | Image Repository | v1.0.8 Tag | v1.0.9 Tag |
|-----------|-----------------|------------|------------|
| Manager | `ghcr.io/lerianstudio/br-sta-manager` | `1.4.0` | `1.4.1` |
| Worker | `ghcr.io/lerianstudio/br-sta-worker` | `1.4.0` | `1.4.1` |
| Migrations | `ghcr.io/lerianstudio/br-sta-migrations` | `1.4.0` | `1.4.1` |
| Mock STA | `ghcr.io/lerianstudio/mock-sta-server` | `1.4.0` | `1.4.1` |

### What This Means

- **Manager pods** will be recreated with the new `1.4.1` image
- **Worker pods** will be recreated with the new `1.4.1` image
- **Migrations job** will run with the new `1.4.1` image (if migrations are enabled)
- **Mock STA server** will be updated to `1.4.1` (if mock-sta is enabled)

> **Note:** If you have explicitly overridden image tags in your values.yaml (via `manager.image.tag`, `worker.image.tag`, `migrations.image.tag`, or `mockSta.image.tag`), those overrides will continue to take precedence. Review your custom values to determine if you want to adopt the new default tags.

### Checking for Custom Image Tag Overrides

If you're unsure whether you have custom image tags set, check your current values:

```bash
helm get values br-sta -n br-sta
```

Look for any of these keys in the output:

```yaml
manager:
  image:
    tag: "custom-tag"

worker:
  image:
    tag: "custom-tag"

migrations:
  image:
    tag: "custom-tag"

mockSta:
  image:
    tag: "custom-tag"
```

If these are present and you want to use the new `1.4.1` default, remove them from your values file before upgrading.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.9
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.9
```
