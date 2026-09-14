# Helm Upgrade from v9.1.1 to v9.1.2

## Topics

- **[Fixes](#fixes)**
  - [1. Removal of Grafana configuration block](#1-removal-of-grafana-configuration-block)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Removal of Grafana configuration block

The `grafana` configuration block has been completely removed from the chart's `values.yaml`. This block was previously used to configure Grafana as an observability component but was not actively used or maintained in recent chart versions.

#### What was removed

The following configuration block has been removed from `values.yaml`:

**Before (v9.1.1):**

```yaml
grafana:
  # OpenTelemetry (OTel) dependency for observability.
  # This component is responsible for collecting and exporting telemetry data
  # such as traces and metrics, enhancing the monitoring of the application.
  # For more details, refer to the documentation:
  # https://docs.lerian.studio/docs/observability-in-midaz#midaz-observability-stack
  enabled: false
  name: grafana
  # -- Configure the ingress for Access Grafana Dashboard
  ingress:
    enabled: false
    className: ""
    annotations: {}
    hosts:
      - host: ""
        paths:
          - path: /
            pathType: Prefix
    tls: []
    #  - secretName: chart-example-tls
    #  hosts:
    #      - chart-example.local
```

**After (v9.1.2):**

```yaml
# Configuration block completely removed
```

Additionally, the helper template function `midaz-grafana.fullname` has been removed from `templates/_helpers.tpl`:

**Before (v9.1.1):**

```yaml
{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "midaz-grafana.fullname" -}}
{{- printf "%s-%s" (include "midaz.name" .) .Values.grafana.name | trunc 63 | trimSuffix "-" }}
{{- end }}
```

**After (v9.1.2):**

```yaml
# Helper template removed
```

#### Impact on existing deployments

| Setting | v9.1.1 | v9.1.2 |
|---------|--------|--------|
| `grafana.enabled` | `false` (default) | Removed |
| `grafana.name` | `grafana` | Removed |
| `grafana.ingress.*` | Configurable | Removed |

> **Note:** This removal only affects deployments that explicitly enabled Grafana via `grafana.enabled: true` in their values overrides. Since the default value was `false`, most deployments are unaffected.

#### Migration steps

1. **Check your current values configuration** to see if you have any Grafana-related overrides:

```bash
helm get values midaz -n midaz | grep -A 20 "^grafana:"
```

2. **If you have `grafana.enabled: true` in your values**, you have two options:

   #### Option 1: Remove Grafana configuration

   If you were not actively using the Grafana component, simply remove the `grafana:` block from your values overrides before upgrading.

   #### Option 2: Deploy Grafana separately

   If you need Grafana for observability, deploy it as a separate Helm release using the official Grafana chart:

   ```bash
   helm repo add grafana https://grafana.github.io/helm-charts
   helm repo update
   helm install grafana grafana/grafana -n midaz
   ```

   Then configure your Midaz observability stack to point to the external Grafana instance. Refer to the [Midaz observability documentation](https://docs.lerian.studio/docs/observability-in-midaz#midaz-observability-stack) for integration details.

3. **If you have no Grafana overrides**, no action is required. The upgrade will proceed without issues.

> **Important:** If you have custom templates or scripts that reference the `midaz-grafana.fullname` helper function, update them before upgrading as this function has been removed.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.1.2 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.1.2 -n midaz
```
