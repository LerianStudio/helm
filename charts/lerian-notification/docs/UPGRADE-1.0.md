# Helm Upgrade from v0.x to v1.x

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Migrations Job rewritten to invoke `/migrate` directly](#1-migrations-job-rewritten-to-invoke-migrate-directly)
  - [2. New required value: `secrets.DATABASE_URL`](#2-new-required-value-secretsdatabase_url)
  - [3. PSS-restricted Pod Security Context defaults](#3-pss-restricted-pod-security-context-defaults)
  - [4. Deterministic ConfigMap / Secret key ordering](#4-deterministic-configmap--secret-key-ordering)
  - [5. HPA fails fast when autoscaling is enabled without a target metric](#5-hpa-fails-fast-when-autoscaling-is-enabled-without-a-target-metric)
  - [6. PDB respects explicit `maxUnavailable: 0`](#6-pdb-respects-explicit-maxunavailable-0)
  - [7. Redis retry-backoff defaults corrected](#7-redis-retry-backoff-defaults-corrected)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `lerian-notification` chart upgrade from `0.1.0` to `1.0.0-beta.3`. The application image (`appVersion: 0.1.0`) is unchanged, but the chart is now production-shaped: the migrations Job is rewritten for distroless, the security context defaults align with the Kubernetes Pod Security Standards restricted profile, and several rendering bugs (HPA, PDB, Redis defaults) are fixed.

This is a **breaking** chart upgrade. A new value, `secrets.DATABASE_URL`, is required when `migrations.enabled` is true. Read [Migration Steps](#migration-steps) before upgrading.

## Features

### 1. Migrations Job rewritten to invoke `/migrate` directly

Previously the migrations Job ran a `/bin/sh -ec` script that assembled a DSN at runtime from `POSTGRES_*` env vars (URL-encoding the password with `od | sed`). Starting at `lerian-notification` v1.0.0-beta.2 the API image is distroless and bundles a static `/migrate` binary; there is no shell to run the old script.

The Job now:

- Sets `command: ["/migrate"]` and passes a fixed `args` list (`-path /migrations -database $(DATABASE_URL) ... up`).
- Reads `DATABASE_URL` either from `.Values.secrets.DATABASE_URL` (rendered into the chart's Secret) or, when `.Values.secretRef.name` is set, from a `DATABASE_URL` key inside that externally-managed Secret.
- No longer sets `serviceAccountName` on the hook pod. Helm applies hook resources before the chart's ServiceAccount, so the Job now uses the namespace's default SA, which always exists at hook time.

### 2. New required value: `secrets.DATABASE_URL`

The migrations Job no longer assembles a DSN from `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_HOST` etc. You must provide a pre-built, URL-escaped Postgres DSN:

```yaml
secrets:
  DATABASE_URL: "postgres://USER:URLENCODED_PW@HOST:PORT/DB?sslmode=disable"
```

If you reference an external Secret via `secretRef.name`, that Secret must contain a `DATABASE_URL` key with the same shape.

> **Note:** Special characters in the password must be percent-encoded by the consumer (typically via ArgoCD Vault Plugin or your secrets pipeline) before being placed in `DATABASE_URL`. The chart does not URL-encode at render time.

### 3. PSS-restricted Pod Security Context defaults

Every component (`api`, `migrations`, `workerEmail`, `workerSms`, `workerWebhook`) now ships with the two fields required to land cleanly inside a Pod Security Standards "restricted" namespace:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
```

These are added on top of the existing `runAsNonRoot`, `runAsUser: 65532`, `runAsGroup: 65532`, `capabilities.drop: [ALL]`, and `readOnlyRootFilesystem: true` defaults from v0.1.0.

### 4. Deterministic ConfigMap / Secret key ordering

`templates/configmap.yaml` and `templates/secret.yaml` now iterate keys via `keys ... | sortAlpha` instead of ranging over the map directly. Rendered output is stable, so identical values no longer produce a diff because of Go map iteration order. `extraConfig` also now applies the same version-key exclusion (`VERSION`, `OTEL_RESOURCE_SERVICE_VERSION`, `SWAGGER_VERSION`) that `config` already had.

### 5. HPA fails fast when autoscaling is enabled without a target metric

`templates/api/hpa.yaml` previously rendered an empty `metrics: []` block when neither `targetCPUUtilizationPercentage` nor `targetMemoryUtilizationPercentage` was set, producing an HPA that the API server would reject at apply time. The template now `{{ fail }}`s at render time with a clear message:

```
api.autoscaling.enabled=true requires targetCPUUtilizationPercentage and/or targetMemoryUtilizationPercentage
```

### 6. PDB respects explicit `maxUnavailable: 0`

`templates/api/pdb.yaml` previously used `{{- with .Values.api.pdb.maxUnavailable }}`, which skips the value when it is `0` (Helm's `with` treats `0` as empty). The template now uses an explicit `hasKey` / `ne nil` check, so setting `api.pdb.maxUnavailable: 0` is honored instead of silently falling through to `minAvailable`.

### 7. Redis retry-backoff defaults corrected

The `REDIS_MIN_RETRY_BACKOFF` and `REDIS_MAX_RETRY_BACKOFF` defaults were inverted in v0.1.0 (min `8`, max `1`). They are now `min: 1`, `max: 8`:

| Setting | v0.1.0 | v1.0.0-beta.3 |
|---------|--------|---------------|
| `config.REDIS_MIN_RETRY_BACKOFF` | `"8"` | `"1"` |
| `config.REDIS_MAX_RETRY_BACKOFF` | `"1"` | `"8"` |

## Configuration Changes

Summary of `values.yaml` impact:

| Category | Detail |
|----------|--------|
| Added | `secrets.DATABASE_URL` (required when `migrations.enabled: true`) |
| Added | `allowPrivilegeEscalation: false` + `seccompProfile.type: RuntimeDefault` on `api`, `migrations`, `workerEmail`, `workerSms`, `workerWebhook` securityContext |
| Changed | `config.REDIS_MIN_RETRY_BACKOFF` `"8"` -> `"1"` |
| Changed | `config.REDIS_MAX_RETRY_BACKOFF` `"1"` -> `"8"` |
| Removed | none |

Chart files modified between `0.1.0` and `1.0.0-beta.3`:

- `charts/lerian-notification/Chart.yaml`
- `charts/lerian-notification/values.yaml`
- `charts/lerian-notification/templates/configmap.yaml`
- `charts/lerian-notification/templates/secret.yaml`
- `charts/lerian-notification/templates/migrations-job.yaml`
- `charts/lerian-notification/templates/api/hpa.yaml`
- `charts/lerian-notification/templates/api/pdb.yaml`

## Migration Steps

1. **Build `DATABASE_URL` before upgrading.** Choose one:
   - Inline via values: set `secrets.DATABASE_URL` to a URL-escaped Postgres DSN.
   - External Secret: ensure the Secret referenced by `secretRef.name` contains a `DATABASE_URL` key.
   Without this, the migrations Job will fail with an empty `-database` flag.
2. **Check your Redis settings.** If you explicitly set `REDIS_MIN_RETRY_BACKOFF` or `REDIS_MAX_RETRY_BACKOFF`, the chart defaults are now correct; remove your override if you were working around the old bug.
3. **Audit any HPA override.** If you set `api.autoscaling.enabled: true` without `targetCPUUtilizationPercentage` or `targetMemoryUtilizationPercentage`, the upgrade will now `helm template`-fail with a clear message rather than rendering an invalid HPA. Add at least one target.
4. **Re-check PDB intent.** If you previously set `api.pdb.maxUnavailable: 0` and relied on the buggy fall-through to `minAvailable`, the chart will now honor `0` literally and block all disruptions. Switch to `minAvailable` if that was unintended.
5. Review the rendered diff using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
6. Run the upgrade. The migrations Job runs as a `pre-install` / `pre-upgrade` hook; verify it completed before checking app pods:

```bash
kubectl get jobs -n lerian-notification
kubectl logs -n lerian-notification job/<migrations-job-name>
kubectl rollout status -n lerian-notification deploy/<api-deployment-name>
```

> **Note:** Hook Jobs are removed on success. If the upgrade aborts mid-flight, you can inspect the last failed hook with `helm history -n lerian-notification lerian-notification` and `kubectl get events -n lerian-notification`.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-notification oci://registry-1.docker.io/lerianstudio/lerian-notification-helm --version 1.0.0-beta.3 -n lerian-notification
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-notification oci://registry-1.docker.io/lerianstudio/lerian-notification-helm --version 1.0.0-beta.3 -n lerian-notification
```
