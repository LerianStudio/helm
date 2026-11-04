<!-- {% raw %} -->
# Helm Upgrade from v1.0.0 to v1.0.1

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Metadata URL corrections](#1-metadata-url-corrections)
  - [2. Default environment name changed to `development`](#2-default-environment-name-changed-to-development)
  - [3. Migrations Job now creates its own Secret for pre-install hooks](#3-migrations-job-now-creates-its-own-secret-for-pre-install-hooks)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `notifications` chart upgrade from `1.0.0` to `1.0.1`. This is a **patch** release that corrects chart metadata URLs, changes the default environment name to `development`, and makes the migrations Job read `DATABASE_URL` from a hook Secret when `secretRef.name` is not set. The application version (`appVersion: "1.1.0"`) remains unchanged.

If you have not overridden `config.ENV_NAME` or `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`, both defaults change to `development`.

## Changes

### 1. Metadata URL corrections

The `home` and `sources` URLs in `Chart.yaml` now point to the chart directory in the helm repository. This change is purely cosmetic and does not affect chart behavior or deployment.

### 2. Default environment name changed to `development`

The default value for `config.ENV_NAME` and `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` is now `"development"`.

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

> **Note:** The application's production checks are **only** enabled when `ENV_NAME` is exactly `production`.

Do not set `config.ENV_NAME` back to the previous default: the application accepts only `production`, `staging`, `uat`, `development` or `local`, and exits at startup with any other value. `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` is free text; set it explicitly if your observability queries need its previous value.

### 3. Migrations Job now creates its own Secret for pre-install hooks

In v1.0.0, when `secretRef.name` was not set, the migrations Job received `secrets.DATABASE_URL` as a literal `value:` in its spec.

Starting in v1.0.1, when `secretRef.name` is **not** set, the chart renders a dedicated Secret for the migrations Job, created as a `pre-install` / `pre-upgrade` hook with `helm.sh/hook-weight: "-10"` (before the Job itself, which has weight `-5`). This Secret is populated from `secrets.DATABASE_URL` and is automatically cleaned up on success via `helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded`.

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
        - name: migrate
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
        - name: migrate
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.secretRef.name | default (printf "%s-migrations" (include "notifications.fullname" .)) }}
                  key: DATABASE_URL
```

#### Impact

- **Upgrades:** The hook Secret is recreated before each upgrade and cleaned up after success.
- **External Secret users:** If you set `secretRef.name`, the chart does **not** create the hook Secret; the Job continues to reference your external Secret exactly as before.

> **Important:** The hook Secret is ephemeral and is deleted after the Job succeeds. It is **not** the same as the chart's main Secret (which holds `DATABASE_URL`, `LICENSE_KEY`, and other secrets for the API and worker pods). The main Secret remains a regular release resource and is unaffected by this change.

## Configuration Changes

Summary of `values.yaml` and template impact:

| Category | Detail |
|----------|--------|
| Changed | `config.ENV_NAME` default is now `"development"` |
| Changed | `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` default is now `"development"` |
| Changed | `templates/migrations-job.yaml` now conditionally renders a hook Secret when `secretRef.name` is not set |
| Changed | Chart metadata URLs corrected in `Chart.yaml` |

## Migration Steps

1. **Review your environment name usage.** If you have dashboards, alerts, or log queries that filter on `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT`, update them to `development` or set the value explicitly in your values.

2. **Verify `secrets.DATABASE_URL` is set.** If you are **not** using `secretRef.name`, ensure `secrets.DATABASE_URL` is populated in your values. This was already required in v1.0.0.

3. **Review the rendered diff** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

4. **Run the upgrade.** The migrations Job will run as a `pre-upgrade` hook. Then check the rollout:

```bash
kubectl rollout status -n notifications deploy/<api-deployment-name>
```

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
