<!-- {% raw %} -->
# Helm Upgrade from v1.1.0 to v1.1.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. PostgreSQL image digest pinning](#1-postgresql-image-digest-pinning)
  - [2. PostgreSQL enabled helper logic correction](#2-postgresql-enabled-helper-logic-correction)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `1.1.0` to `1.1.1`. The application version remains `1.0.0-beta.9`; the chart bump to `1.1.1` is a patch release that introduces two fixes: the PostgreSQL image is now pinned to a specific digest to prevent unintended major version upgrades, and the `postgresql.enabled` helper template logic was corrected to properly handle boolean values.

This upgrade requires no operator action beyond running the upgrade command. Existing deployments will continue to work without values changes.

## Fixes

### 1. PostgreSQL image digest pinning

The PostgreSQL subchart image configuration now includes a SHA256 digest pin to lock the image to PostgreSQL 18.6.0. Previously, the chart used `tag: "latest"` without a digest, which allowed the image to float to newer major versions. PostgreSQL refuses to start when the data directory was initialized by a different major version, so an unintended image pull could cause the database to fail to start.

**Before (v1.1.0):**

```yaml
postgresql:
  image:
    repository: bitnamisecure/postgresql
    tag: "latest"
```

**After (v1.1.1):**

```yaml
postgresql:
  image:
    repository: bitnamisecure/postgresql
    tag: "latest"
    # latest (PostgreSQL 18.6.0), pinned: PostgreSQL refuses a data directory of another major.
    digest: "sha256:7045d816bdf7e704f0f662fabf243f3c0a975aa380e73e4e881ee94740f60d4f"
```

> **Note:** The digest corresponds to PostgreSQL 18.6.0. If your existing deployment is running an older major version (e.g., PostgreSQL 15 or 16), the upgrade will attempt to pull the pinned 18.6.0 image. PostgreSQL will refuse to start if the data directory major version does not match. Verify your current PostgreSQL version before upgrading.

> **Warning:** If you override `postgresql.image.tag` or `postgresql.image.digest` in your values overlay, ensure the digest matches the tag's major version. Mismatched digest and tag will cause image pull errors.

### 2. PostgreSQL enabled helper logic correction

The `postgresql.enabled` helper template in `templates/_helpers.tpl` was updated to correctly evaluate boolean values. The previous logic used `default true .Values.postgresql.enabled`, which did not properly handle explicit `false` values when `postgresql.enabled` was set to `false` as a boolean. The new logic converts the value to a string and compares it against `"false"`, ensuring that `postgresql.enabled: false` is respected.

**Before (v1.1.0):**

```yaml
{{- define "postgresql.enabled" -}}
{{- if and (default true .Values.postgresql.enabled) (not .Values.postgresql.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
```

**After (v1.1.1):**

```yaml
{{- define "postgresql.enabled" -}}
{{- if and (ne (.Values.postgresql.enabled | toString) "false") (not .Values.postgresql.external) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
```

**Operational impact:**

Deployments that explicitly set `postgresql.enabled: false` in their values overlay will now correctly skip the PostgreSQL subchart resources. In v1.1.0, the helper would incorrectly evaluate `false` as truthy due to the `default true` logic, causing the subchart to be rendered even when disabled.

If you rely on an external PostgreSQL instance and set `postgresql.enabled: false`, verify after the upgrade that no PostgreSQL StatefulSet, Service, or PVC resources are present in your namespace:

```bash
kubectl get statefulset,service,pvc -n <namespace> -l app.kubernetes.io/name=postgresql
```

## Configuration Changes

| Setting | v1.1.0 | v1.1.1 |
|---------|--------|--------|
| `postgresql.image.digest` | not set | `"sha256:7045d816bdf7e704f0f662fabf243f3c0a975aa380e73e4e881ee94740f60d4f"` |

No other configuration values were added, removed, or changed. The `postgresql.enabled` helper logic change does not introduce new values; it corrects the evaluation of the existing `postgresql.enabled` boolean flag.

## Migration Steps

1. **(Optional)** If you override `postgresql.image.tag` or `postgresql.image.digest` in your values overlay, verify that the digest matches the PostgreSQL major version of your existing data directory. If you are running PostgreSQL 15, 16, or 17, you must either:
   - Keep your existing image override and skip the digest pin, or
   - Plan a PostgreSQL major version upgrade (outside the scope of this chart upgrade)

2. **(Optional)** If you set `postgresql.enabled: false` in your values overlay, verify after the upgrade that the PostgreSQL subchart resources are not rendered:

```bash
kubectl get statefulset,service,pvc -n <namespace> -l app.kubernetes.io/name=postgresql
```

3. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

5. If the PostgreSQL StatefulSet is managed by this chart, confirm the image digest matches the pinned value:

```bash
kubectl get statefulset -n <namespace> -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
```

Expected output:

```
bitnamisecure/postgresql@sha256:7045d816bdf7e704f0f662fabf243f3c0a975aa380e73e4e881ee94740f60d4f
```

> **Important:** If the PostgreSQL pod fails to start after the upgrade with an error message about incompatible data directory versions, you are running a different PostgreSQL major version than 18.6.0. Roll back the chart upgrade and plan a PostgreSQL major version migration before upgrading to v1.1.1.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.1.1 -n plugin-br-payments
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 1.1.1 -n plugin-br-payments
```
<!-- {% endraw %} -->
