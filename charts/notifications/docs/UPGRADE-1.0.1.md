<!-- {% raw %} -->
# Helm Upgrade from v1.0.0 to v1.0.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Metadata URL corrections](#1-metadata-url-corrections)
  - [2. Default environment name changed from `firmino` to `development`](#2-default-environment-name-changed-from-firmino-to-development)
  - [3. Migrations Job now creates its own Secret for pre-install hooks](#3-migrations-job-now-creates-its-own-secret-for-pre-install-hooks)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `notifications` chart upgrade from `1.0.0` to `1.0.1`. This is a **patch** release that corrects chart metadata URLs, changes the default environment name from `firmino` to `development`, and fixes a timing issue where the migrations Job could fail at pre-install time when `secretRef.name` was not set. The application version (`appVersion: "1.1.0"`) remains unchanged.

This upgrade is **non-breaking** for most installations. If you have not overridden `config.ENV_NAME` or `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`, the defaults will change from `firmino` to `development`. If you rely on the exact value `firmino` in your monitoring or logging pipelines, you must explicitly set it in your values before upgrading.

## Fixes

### 1. Metadata URL corrections

The chart's `home` and `sources` URLs in `Chart.yaml` now point to the correct repository paths:

| Field | v1.0.0 | v1.0.1 |
|-------|--------|--------|
| `home` | `https://github.com/LerianStudio/helm` | `https://github.com/LerianStudio/helm/tree/main/charts/notifications` |
| `sources[0]` | `https://github.com/LerianStudio/notifications` | `https://github.com/LerianStudio/helm/tree/main/charts/notifications` |

This change is purely cosmetic and does not affect chart behavior or deployment.

### 2. Default environment name changed from `firmino` to `development`

The default value for `config.ENV_NAME` and `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` has been changed from `firmino` to `development`:

| Setting | v1.0.0 | v1.0.1 |
|---------|--------|--------|
| `config.ENV_NAME` | `"firmino"` | `"development"` |
| `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | `"firmino"` | `"development"` |

**Before (v1.0.0):**

```yaml
config:
  # -- Only the exact value `production` turns on the app's production checks
  #    (Swagger forced off, rate limiting forced on, POSTGRES_PASSWORD required,
  #    sslmode=disable and dev encryption keys refused). Any other value,
  #    including the default `firmino`, leaves them off.
  ENV_NAME: "firmino"
  # ...
  OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "firmino"
```

**After (v1.0.1):**

```yaml
config:
  # -- Only the exact value `production` turns on the app's production checks
  #    (Swagger forced off, rate limiting forced on, POSTGRES_PASSWORD required,
  #    sslmode=disable and dev encryption keys refused). Any other value,
  #    including the default `development`, leaves them off.
  ENV_NAME: "development"
  # ...
  OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "development"
```

> **Note:** The application's production checks are **only** enabled when `ENV_NAME` is exactly `production`. Both `firmino` and `development` are treated as non-production environments. This change normalizes the default to a more conventional name.

#### Impact

- **Logging and metrics:** If your observability stack filters or groups by `ENV_NAME` or `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`, logs and traces will now appear under `development` instead of `firmino` after the upgrade.
- **Application behavior:** No functional change. The application treats both `firmino` and `development` identically (non-production mode).

#### Migration options

##### Option 1: Accept the new default

If you do not rely on the exact string `firmino` in your monitoring dashboards, alerts, or log queries, no action is required. The upgrade will automatically switch to `development`.

##### Option 2: Preserve `firmino`

If you need to keep the old value for continuity in your observability pipelines, explicitly set it in your values:

```yaml
config:
  ENV_NAME: "firmino"
  OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "firmino"
```

### 3. Migrations Job now creates its own Secret for pre-install hooks

The migrations Job previously read `DATABASE_URL` either from the chart's main Secret (when `secretRef.name` was not set) or from an external Secret (when `secretRef.name` was set). However, the chart's main Secret is a regular release resource and does not exist at `pre-install` hook time, causing the Job to fail on fresh installs when `secretRef.name` was not configured.

Starting in v1.0.1, when `secretRef.name` is **not** set, the chart now renders a dedicated Secret for the migrations Job, created as a `pre-install` / `pre-upgrade` hook with `helm.sh/hook-weight: "-10"` (before the Job itself, which has the default weight `0`). This Secret is populated from `secrets.DATABASE_URL` and is automatically cleaned up on success via `helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded`.

**Before (v1.0.0):**

```yaml
# templates/migrations-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  # ...
spec:
  template:
    spec:
      containers:
        - name: migrations
          env:
            - name: DATABASE_URL
              {{- if .Values.secretRef.name }}
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.secretRef.name }}
                  key: DATABASE_URL
              {{- else }}
              value: {{ .Values.secrets.DATABASE_URL | quote }}
              {{- end }}
```

**After (v1.0.1):**

```yaml
# templates/migrations-job.yaml
{{- if not .Values.secretRef.name }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "notifications.fullname" . }}-migrations
  namespace: {{ include "notifications.namespace" . }}
  labels:
    {{- include "notifications.labels" (dict "context" . "name" (printf "%s-migrations" (include "notifications.fullname" .))) | nindent 4 }}
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-10"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
type: Opaque
data:
  DATABASE_URL: {{ .Values.secrets.DATABASE_URL | default "" | b64enc | quote }}
---
{{- end }}
apiVersion: batch/v1
kind: Job
metadata:
  # ...
spec:
  template:
    spec:
      containers:
        - name: migrations
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.secretRef.name | default (printf "%s-migrations" (include "notifications.fullname" .)) }}
                  key: DATABASE_URL
```

#### Impact

- **Fresh installs:** The migrations Job will now succeed on first install when `secretRef.name` is not set, as long as `secrets.DATABASE_URL` is provided.
- **Upgrades:** No change in behavior. The hook Secret is recreated before each upgrade and cleaned up after success.
- **External Secret users:** If you set `secretRef.name`, the chart does **not** create the hook Secret; the Job continues to reference your external Secret exactly as before.

> **Important:** The hook Secret is ephemeral and is deleted after the Job succeeds. It is **not** the same as the chart's main Secret (which holds `DATABASE_URL`, `LICENSE_KEY`, and other secrets for the API and worker pods). The main Secret remains a regular release resource and is unaffected by this change.

## Configuration Changes

Summary of `values.yaml` and template impact:

| Category | Detail |
|----------|--------|
| Changed | `config.ENV_NAME` default: `"firmino"` → `"development"` |
| Changed | `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` default: `"firmino"` → `"development"` |
| Changed | `templates/migrations-job.yaml` now conditionally renders a hook Secret when `secretRef.name` is not set |
| Changed | Chart metadata URLs corrected in `Chart.yaml` |

## Migration Steps

1. **Review your environment name usage.** If you have dashboards, alerts, or log queries that filter on `ENV_NAME=firmino` or `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT=firmino`, decide whether to:
   - Update your queries to use `development` (recommended), or
   - Explicitly set `config.ENV_NAME: "firmino"` and `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "firmino"` in your values to preserve the old default.

2. **Verify `secrets.DATABASE_URL` is set.** If you are **not** using `secretRef.name`, ensure `secrets.DATABASE_URL` is populated in your values. This was already required in v1.0.0; v1.0.1 simply fixes the hook timing so the Job can read it correctly at pre-install time.

3. **Review the rendered diff** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

4. **Run the upgrade.** The migrations Job will run as a `pre-upgrade` hook. Verify it completed successfully:

```bash
kubectl get jobs -n notifications
kubectl logs -n notifications job/<migrations-job-name>
kubectl rollout status -n notifications deploy/<api-deployment-name>
```

> **Note:** If you are performing a fresh install (not an upgrade), the migrations Job will now succeed on the first attempt when `secretRef.name` is not set, as long as `secrets.DATABASE_URL` is provided.

## Preview changes before upgrading

```bash
helm diff upgrade notifications oci://registry-1.docker.io/lerianstudio/notifications-helm --version 1.0.1 -n notifications
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade notifications oci://registry-1.docker.io/lerianstudio/notifications-helm --version 1.0.1 -n notifications
```
<!-- {% endraw %} -->
