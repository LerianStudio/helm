<!-- {% raw %} -->
# Helm Upgrade from v10.0.5 to v10.1.0

## Topics

- **[Features](#features)**
  - [1. Optional LICENSE_KEY value for ledger and tracer](#1-optional-license_key-value-for-ledger-and-tracer)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Optional LICENSE_KEY value for ledger and tracer

This release adds the optional values `ledger.secrets.LICENSE_KEY` and `tracer.secrets.LICENSE_KEY` (default `""`). When a value is set, the chart writes it as `LICENSE_KEY` into the service Secret. When the value is empty, the chart leaves the key out. The ledger and tracer images this chart version deploys (`4.4.0`, unchanged from v10.0.5) do not read `LICENSE_KEY`. No action is required for this upgrade.

#### What changed

| Service | Setting | v10.0.5 | v10.1.0 |
|---------|---------|---------|---------|
| ledger | `ledger.secrets.LICENSE_KEY` | (not present) | `""` (empty string) |
| tracer | `tracer.secrets.LICENSE_KEY` | (not present) | `""` (empty string) |

The default value for both fields is an empty string.

#### Operational impact

- Pods roll once. The chart version is part of the `helm.sh/chart` label in the pod templates, so any chart version bump, including this one, triggers a rolling restart of the Midaz pods.
- The ledger migrations Job runs as a `pre-upgrade` hook on every upgrade, including this one.
- The `LICENSE_KEY` is stored in the Kubernetes Secret for each service and base64-encoded by the template.

## Configuration Reference

The following new secret fields are available in v10.1.0:

| Field | Service | Type | Default | Description |
|-------|---------|------|---------|-------------|
| `ledger.secrets.LICENSE_KEY` | ledger | string | `""` | Product license key. Written into the service Secret as `LICENSE_KEY` when set. |
| `tracer.secrets.LICENSE_KEY` | tracer | string | `""` | Product license key. Written into the service Secret as `LICENSE_KEY` when set. |

When set, each value is base64-encoded into the service Secret, which the pods load as environment variables.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.1.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.1.0 -n midaz
```
<!-- {% endraw %} -->
