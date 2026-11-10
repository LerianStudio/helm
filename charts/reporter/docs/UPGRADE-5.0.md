<!-- {% raw %} -->
# Helm Upgrade from v4.x to v5.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Application version bump to 4.5.1](#1-application-version-bump-to-451)
  - [2. New helper template for boolean flag defaults](#2-new-helper-template-for-boolean-flag-defaults)
  - [3. ALLOW_INSECURE_TLS now defaults to true correctly](#3-allow_insecure_tls-now-defaults-to-true-correctly)
  - [4. RabbitMQ definitions now use toRawJson](#4-rabbitmq-definitions-now-use-torawjson)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a major release that bumps the application version to `4.5.1` and introduces a new helper template to correctly handle boolean flag defaults. The primary fix addresses the `ALLOW_INSECURE_TLS` configuration flag, which now properly defaults to `"true"` when not explicitly set. Additionally, the RabbitMQ definitions Secret now uses `toRawJson` instead of `toJson` for more predictable JSON serialization.

| Field | v4.5.0 | v5.0.0 |
|-------|--------|--------|
| Chart version | `4.5.0` | `5.0.0` |
| App version | `4.5.0` | `4.5.1` |
| Manager image tag | `4.5.0` | `4.5.1` |
| Worker image tag | `4.5.0` | `4.5.1` |

## Features

### 1. Application version bump to 4.5.1

The manager and worker image tags have been updated from `4.5.0` to `4.5.1`, and the chart `appVersion` field reflects this change.

| Component | v4.5.0 | v5.0.0 |
|-----------|--------|--------|
| `manager.image.tag` | `"4.5.0"` | `"4.5.1"` |
| `worker.image.tag` | `"4.5.0"` | `"4.5.1"` |
| Chart `appVersion` | `"4.5.0"` | `"4.5.1"` |

### 2. New helper template for boolean flag defaults

A new helper template `reporter.flagDefaultTrue` has been added to `_helpers.tpl` to correctly handle boolean flags that should default to `"true"`. This template addresses a limitation in Sprig's `default` function, which treats an explicit boolean `false` as an empty value.

**Template definition:**

```yaml
{{- define "reporter.flagDefaultTrue" -}}
{{- if kindIs "bool" . }}{{ . }}{{ else }}{{ . | default "true" }}{{ end -}}
{{- end }}
```

**How it works:**

- If the input is a boolean type (e.g., `true` or `false`), it renders the boolean as-is
- If the input is a string or empty, it applies the default value `"true"`

This ensures that operators can explicitly set a flag to `false` without the template overriding it with the default.

### 3. ALLOW_INSECURE_TLS now defaults to true correctly

The `ALLOW_INSECURE_TLS` environment variable in the manager and worker ConfigMaps now uses the new `reporter.flagDefaultTrue` helper template. This fixes a bug where the flag would not default to `"true"` when left unset, causing TLS connection failures in default installations.

**Before (v4.5.0):**

```yaml
ALLOW_INSECURE_TLS: {{ $cm.ALLOW_INSECURE_TLS | default "true" | quote }}
```

**After (v5.0.0):**

```yaml
ALLOW_INSECURE_TLS: {{ include "reporter.flagDefaultTrue" $cm.ALLOW_INSECURE_TLS | quote }}
```

| Setting | v4.5.0 | v5.0.0 | Notes |
|---------|--------|--------|-------|
| `manager.configmap.ALLOW_INSECURE_TLS` (default) | `"true"` (via `default` function) | `"true"` (via `reporter.flagDefaultTrue` helper) | Now correctly handles explicit `false` |
| `worker.configmap.ALLOW_INSECURE_TLS` (default) | `"true"` (via `default` function) | `"true"` (via `reporter.flagDefaultTrue` helper) | Now correctly handles explicit `false` |

**Operational impact:**

- If you have not set `manager.configmap.ALLOW_INSECURE_TLS` or `worker.configmap.ALLOW_INSECURE_TLS` in your values, the behavior remains unchanged — the flag defaults to `"true"`
- If you have explicitly set the flag to `false` (boolean or string), it will now be respected correctly

**Example override to disable insecure TLS:**

```yaml
manager:
  configmap:
    ALLOW_INSECURE_TLS: false

worker:
  configmap:
    ALLOW_INSECURE_TLS: false
```

> **Note:** The convention for this chart is to default `ALLOW_INSECURE_TLS` to `"true"` for the bundled deployment path. Managed-cloud profiles should explicitly set this to `false` in their values overrides.

### 4. RabbitMQ definitions now use toRawJson

The manager's RabbitMQ definitions Secret (`reporter-manager-load-definitions`) now uses the `toRawJson` function instead of `toJson` when serializing the definitions JSON. This change ensures more predictable JSON output without HTML escaping.

**Before (v4.5.0):**

```yaml
data:
  load_definition.json: {{ toJson $defs | b64enc | quote }}
```

**After (v5.0.0):**

```yaml
data:
  load_definition.json: {{ toRawJson $defs | b64enc | quote }}
```

**Operational impact:**

- The RabbitMQ definitions Secret will be updated during the upgrade
- The functional behavior of the definitions remains unchanged — this is a serialization improvement only
- No action is required from operators

> **Note:** `toRawJson` is available in Helm 3.1+ and produces JSON without HTML entity escaping (e.g., `&` remains `&` instead of becoming `\u0026`).

## Configuration Changes

No `values.yaml` keys were added, removed, or renamed. The changes are in template logic only.

| Setting | v4.5.0 | v5.0.0 | Notes |
|---------|--------|--------|-------|
| `manager.image.tag` | `"4.5.0"` | `"4.5.1"` | Application version bump |
| `worker.image.tag` | `"4.5.0"` | `"4.5.1"` | Application version bump |
| `manager.configmap.ALLOW_INSECURE_TLS` (template logic) | `default "true"` | `reporter.flagDefaultTrue` helper | Now correctly handles explicit boolean `false` |
| `worker.configmap.ALLOW_INSECURE_TLS` (template logic) | `default "true"` | `reporter.flagDefaultTrue` helper | Now correctly handles explicit boolean `false` |

## Migration Steps

This upgrade requires no mandatory values changes. The Helm upgrade will roll the manager and worker deployments to the new `4.5.1` image tag and update the RabbitMQ definitions Secret.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Confirm that your values do not rely on the previous behavior of `ALLOW_INSECURE_TLS`. If you have explicitly set this flag to `false` as a string (e.g., `ALLOW_INSECURE_TLS: "false"`), verify that it is now set as a boolean:

   ```yaml
   manager:
     configmap:
       ALLOW_INSECURE_TLS: false
   
   worker:
     configmap:
       ALLOW_INSECURE_TLS: false
   ```

3. Run the upgrade command during a maintenance window.

4. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n <namespace>
   ```

5. Check manager and worker logs to confirm TLS behavior:

   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
   kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
   ```

6. Verify the RabbitMQ definitions Secret was updated:

   ```bash
   kubectl get secret -n <namespace> reporter-manager-load-definitions -o jsonpath='{.data.load_definition\.json}' | base64 -d | jq .
   ```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. The RabbitMQ definitions Secret will be updated, but this does not trigger a RabbitMQ pod restart unless the definitions content has changed functionally.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.0.0 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.0.0 -n <namespace>
```
<!-- {% endraw %} -->
