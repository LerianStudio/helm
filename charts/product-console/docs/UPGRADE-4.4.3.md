<!-- {% raw %} -->
# Helm Upgrade from v4.4.2 to v4.4.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Application version updated to 2.13.0](#1-application-version-updated-to-2130)
  - [2. Readiness probe documentation clarified for console 2.0+](#2-readiness-probe-documentation-clarified-for-console-20)
  - [3. ALLOWED_ORIGINS default behavior clarified](#3-allowed_origins-default-behavior-clarified)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application image to version 2.13.0 and clarifies documentation around readiness probe behavior and ALLOWED_ORIGINS defaults. No breaking changes or mandatory configuration updates are required.

| Field | v4.4.2 | v4.4.3 |
|-------|--------|--------|
| Chart version | `4.4.2` | `4.4.3` |
| App version | `2.12.0` | `2.13.0` |
| Image tag | `2.12.0` | `2.13.0` |

## Fixes

### 1. Application version updated to 2.13.0

The default application image has been updated from `2.12.0` to `2.13.0`. This is reflected in both `Chart.yaml` (`appVersion`) and `values.yaml` (`image.tag`).

| Setting | v4.4.2 | v4.4.3 |
|---------|--------|--------|
| `appVersion` | `2.12.0` | `2.13.0` |
| `image.tag` | `2.12.0` | `2.13.0` |

**Impact:**

The upgrade will pull the new image and trigger a rolling restart of the deployment. No configuration changes are required unless you have explicitly pinned `image.tag` in your values file.

> **Note:** Console images from 2.0 onward connect to MongoDB at startup (not on first request), so the readiness probe deadlock described in earlier documentation no longer applies to this image.

### 2. Readiness probe documentation clarified for console 2.0+

The documentation in `values.yaml`, `deployment.yaml`, and `NOTES.txt` has been updated to clarify that console images from version 2.0 onward connect to MongoDB at startup, eliminating the readiness probe deadlock that affected earlier versions.

**Key clarifications:**

- Console images **before 2.0** opened the MongoDB connection on the first request that needed it, causing a deadlock when readiness was set to `/api/admin/health/readyz` (not Ready → no traffic → no connection → never Ready)
- Console images **from 2.0 onward** (including the image pinned in this chart) connect to MongoDB at startup, so the deadlock no longer occurs
- The default readiness path remains `/api/admin/health/alive` (MongoDB-independent) to preserve existing behavior for operators upgrading from earlier chart versions
- Operators running console 2.0+ images can safely set `readinessProbe.path: /api/admin/health/readyz` to gate readiness on the database connection

**Before (v4.4.2):**

```yaml
# Defaults to '/api/admin/health/alive', which does NOT gate on MongoDB. The
# image this chart pins opens its database connection on the first request that
# needs one, so readiness on '/api/admin/health/readyz' deadlocks a fresh pod:
# not Ready, no traffic, no connection, never Ready. Set
#   readinessProbe:
#     path: /api/admin/health/readyz
# once you run an image that connects at startup, to gate readiness on the
# database again.
readinessProbe: {}
```

**After (v4.4.3):**

```yaml
# Defaults to '/api/admin/health/alive', which does NOT gate on MongoDB.
# Console images before 2.0 opened their database connection on the first
# request that needed one, so readiness on '/api/admin/health/readyz'
# deadlocked a fresh pod: not Ready, no traffic, no connection, never Ready.
# From 2.0 on the console connects at startup, so the image pinned in image.tag
# does not deadlock; 'alive' stays the default so existing installs are
# unchanged. Set
#   readinessProbe:
#     path: /api/admin/health/readyz
# (only on a console image from 2.0 on) to gate readiness on the database.
readinessProbe: {}
```

**Impact:**

This is a documentation-only change. The default readiness probe path remains `/api/admin/health/alive`. Operators who wish to gate readiness on MongoDB can now safely set:

```yaml
readinessProbe:
  path: /api/admin/health/readyz
```

> **Important:** Only set `readinessProbe.path: /api/admin/health/readyz` if you are running a console image from version 2.0 or later. On older images, this will cause the pod to deadlock and never become Ready.

### 3. ALLOWED_ORIGINS default behavior clarified

The `ALLOWED_ORIGINS` environment variable documentation in `configmap.yaml` has been updated to clarify its default behavior and fallback logic.

**Key clarifications:**

- `ALLOWED_ORIGINS` gates the application's CSRF guard and blocks all mutating requests (except a small public allow-list including `/api/auth/*`) when empty
- The default value is now explicitly the **ingress origin** (`https://<first ingress host>`), **not** `NEXTAUTH_URL`
- `NEXTAUTH_URL` falls back to `http://localhost:8081` when there is no ingress host, but `ALLOWED_ORIGINS` falls back to **empty** in that case, blocking all writes
- Operators must set `ALLOWED_ORIGINS` explicitly whenever there is no ingress host or the browser-facing origin differs from the ingress host

**Before (v4.4.2):**

```yaml
{{- /* ALLOWED_ORIGINS (CSV) gates the app's own CSRF guard (rejects every
   mutating request outside /api/auth/* when unset) — not part of any
   lerian-common mask; defaults to the same origin as NEXTAUTH_URL since
   that's virtually always what operators want (the app calling itself). */}}
ALLOWED_ORIGINS: {{ $cm.ALLOWED_ORIGINS | default $ingressOrigin | quote }}
```

**After (v4.4.3):**

```yaml
{{- /* ALLOWED_ORIGINS (CSV) gates the app's own CSRF guard (rejects every
   mutating request outside its small public allow-list, /api/auth/* among
   them, when empty) — not part of any lerian-common mask. It defaults to
   the ingress origin ($ingressOrigin, "https://<first ingress host>"), NOT
   to NEXTAUTH_URL: NEXTAUTH_URL falls back to http://localhost:8081 when
   there is no ingress host, ALLOWED_ORIGINS falls back to empty, and an
   empty value blocks every write. Set it explicitly whenever there is no
   ingress host or the browser-facing origin differs from it. */}}
ALLOWED_ORIGINS: {{ $cm.ALLOWED_ORIGINS | default $ingressOrigin | quote }}
```

**Impact:**

This is a documentation-only change. The template logic remains unchanged. Operators should verify that `ALLOWED_ORIGINS` is set correctly if:

- There is no ingress host configured (the chart will default to empty, blocking writes)
- The browser-facing origin differs from the first ingress host

**Example override when there is no ingress:**

```yaml
configmap:
  ALLOWED_ORIGINS: "http://localhost:8081"
```

**Example override when the browser-facing origin differs:**

```yaml
configmap:
  ALLOWED_ORIGINS: "https://console.example.com,https://console-staging.example.com"
```

> **Warning:** An empty `ALLOWED_ORIGINS` value will block all mutating requests outside the public allow-list. If you are not using an ingress, you must set this value explicitly.

## Configuration Changes

No configuration keys were added, removed, or renamed. All changes are documentation clarifications and the application image version bump.

| Setting | v4.4.2 | v4.4.3 | Notes |
|---------|--------|--------|-------|
| `image.tag` | `2.12.0` | `2.13.0` | Application image updated |
| `readinessProbe` | `{}` | `{}` | Documentation clarified; default behavior unchanged |
| `configmap.ALLOWED_ORIGINS` | defaults to `$ingressOrigin` | defaults to `$ingressOrigin` | Documentation clarified; template logic unchanged |

## Migration Steps

This upgrade requires no mandatory configuration changes. The Helm upgrade will update the image tag and trigger a rolling restart.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n product-console
```

4. Check service logs for any startup or probe failures:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50
```

5. **(Optional)** If you wish to gate readiness on MongoDB, set:

```yaml
readinessProbe:
  path: /api/admin/health/readyz
```

6. **(Optional)** If you are not using an ingress or the browser-facing origin differs from the ingress host, verify that `ALLOWED_ORIGINS` is set explicitly:

```yaml
configmap:
  ALLOWED_ORIGINS: "https://console.example.com"
```

> **Note:** The upgrade triggers a rolling restart of the `product-console` deployment. Pods will pull the new `2.13.0` image.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.3 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.4.3 -n product-console
```
<!-- {% endraw %} -->
