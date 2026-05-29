# Helm Upgrade from v0.x to v1.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Rename PROVIDER_* values to BTG_*](#1-rename-provider_-values-to-btg_)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `0.1.0` to `1.0.0`. The application version remains `1.0.0-beta.9`; the chart bump to `1.0.0` carries a single breaking change: the provider integration value keys were renamed from the generic `PROVIDER_*` prefix to the vendor-specific `BTG_*` prefix to match the names the running binary actually reads.

Existing deployments must rename these keys in their values overlays in the same change set that pins the chart to `1.0.0`. The previous `PROVIDER_*` keys were never consumed by the application binary, so any environment that relied on them was already running without provider integration.

## Features

### 1. Rename PROVIDER_* values to BTG_*

All provider integration keys were renamed from `PROVIDER_*` to `BTG_*` across `values.yaml`, `values-template.yaml`, `templates/_helpers.tpl`, `templates/NOTES.txt`, and `README.md`. The chart `fail` hooks were updated accordingly, so a deployment that still sets the old keys will be rejected at install/upgrade time with an explicit error.

| Section | Previous (v0.x) | Current (v1.0.0) |
|---------|-----------------|------------------|
| `app.configmap` | `PROVIDER_API_BASE_URL` | `BTG_API_BASE_URL` |
| `app.configmap` | `PROVIDER_AUTH_URL` | `BTG_AUTH_URL` |
| `app.configmap` | `PROVIDER_TOKEN_REFRESH_INTERVAL` | `BTG_TOKEN_REFRESH_INTERVAL` |
| `app.secrets` | `PROVIDER_CLIENT_ID` | `BTG_CLIENT_ID` |
| `app.secrets` | `PROVIDER_CLIENT_SECRET` | `BTG_CLIENT_SECRET` |
| `app.secrets` | `PROVIDER_WEBHOOK_SECRET` | `BTG_WEBHOOK_SECRET` |

Updated `values.yaml` fragment:

```yaml
app:
  configmap:
    # BTG Provider Integration (REQUIRED - validated by helper)
    BTG_API_BASE_URL: ""
    BTG_AUTH_URL: ""
    BTG_TOKEN_REFRESH_INTERVAL: "1h"
  secrets:
    # BTG OAuth2 (REQUIRED)
    BTG_CLIENT_ID: ""
    BTG_CLIENT_SECRET: ""
    BTG_WEBHOOK_SECRET: ""
```

> **Note:** The application reads only the `BTG_*` names (see `internal/bootstrap/config.go` in `plugin-br-payments`). Environments that previously set `PROVIDER_*` keys were not driving the token reconciliation worker, even if the chart accepted the values.

## Configuration Changes

The only configuration change in v1.0.0 is the rename described above. No new values were added, no values were removed beyond the rename, and no defaults for image, resources, probes, ingress, service, or replica counts were changed.

| Setting | v0.x | v1.0.0 |
|---------|------|--------|
| `app.configmap.PROVIDER_API_BASE_URL` | present | removed (renamed) |
| `app.configmap.PROVIDER_AUTH_URL` | present | removed (renamed) |
| `app.configmap.PROVIDER_TOKEN_REFRESH_INTERVAL` | present | removed (renamed) |
| `app.secrets.PROVIDER_CLIENT_ID` | present | removed (renamed) |
| `app.secrets.PROVIDER_CLIENT_SECRET` | present | removed (renamed) |
| `app.secrets.PROVIDER_WEBHOOK_SECRET` | present | removed (renamed) |
| `app.configmap.BTG_API_BASE_URL` | n/a | required |
| `app.configmap.BTG_AUTH_URL` | n/a | required |
| `app.configmap.BTG_TOKEN_REFRESH_INTERVAL` | n/a | `"1h"` default |
| `app.secrets.BTG_CLIENT_ID` | n/a | required |
| `app.secrets.BTG_CLIENT_SECRET` | n/a | required |
| `app.secrets.BTG_WEBHOOK_SECRET` | n/a | required |

## Migration Steps

1. Update every values overlay that targets this chart to use the `BTG_*` keys instead of `PROVIDER_*`. Any leftover `PROVIDER_*` keys will be ignored by the chart (they no longer have a template binding).
2. Verify the renamed keys against the snippet above. The chart fails fast at install/upgrade time if any of the required `BTG_*` keys are empty.
3. Preview the rendered diff with the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
4. Run the upgrade command during a maintenance window.
5. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

6. Check service logs to confirm the token reconciliation worker reaches the BTG endpoints:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=plugin-br-payments-helm --tail=100
```

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.0.0 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.0.0 -n <namespace>
```
