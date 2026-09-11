# Helm Upgrade from v9.2.3 to v9.2.4

# Topics

- **[Fixes](#fixes)**
  - [1. Migration Image Repository Validation](#1-migration-image-repository-validation)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Migration Image Repository Validation

This release adds runtime validation to prevent a common misconfiguration where operators accidentally use the legacy `casdoor-migrations` image with the v9.x chart, which causes migration job failures.

**What changed:**

The `caradhras.migrationsImageRepository` helper template now includes a validation check that fails the Helm deployment if the resolved migration image repository contains `casdoor-migrations`.

**Before (v9.2.3):**

```yaml
{{- define "caradhras.migrationsImageRepository" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.repository "oldVal" (dig "backend" "migrations" "image" "repository" "" .Values.auth) "default" "ghcr.io/lerianstudio/caradhras-migrations") -}}
{{- end }}
```

**After (v9.2.4):**

```yaml
{{- define "caradhras.migrationsImageRepository" -}}
{{- $repo := include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.repository "oldVal" (dig "backend" "migrations" "image" "repository" "" .Values.auth) "default" "ghcr.io/lerianstudio/caradhras-migrations") -}}
{{- if contains "casdoor-migrations" $repo -}}
{{- fail (printf "\n\nplugin-access-manager: the migration image repository resolves to %q, which points at the OLD casdoor-migrations image.\nOn v9.x the migration Job injects POSTGRES_* env vars, but casdoor-migrations reads DB_* and will fail at runtime with:\n  Missing required environment variables: DB_USER, DB_PASS, DB_HOST, DB_NAME\nIt is NOT a downgrade of casdoor:3.1.0 — caradhras-migrations 1.2.x is a different product line.\nSet caradhras.migrations.image.repository to ghcr.io/lerianstudio/caradhras-migrations (or leave it empty to accept the default),\nand clear any legacy auth.backend.migrations.image.repository override.\nSee docs/UPGRADE-8.6-to-9.2.md (Known Gotchas)." $repo) -}}
{{- end -}}
{{- $repo -}}
{{- end }}
```

**Why this matters:**

In v9.x, the migration job was refactored to use `POSTGRES_*` environment variables instead of `DB_*` variables. If you have a values override that still references the old `casdoor-migrations` image (either via `caradhras.migrations.image.repository` or the legacy `auth.backend.migrations.image.repository` path), the migration job will fail at runtime with:

```
Missing required environment variables: DB_USER, DB_PASS, DB_HOST, DB_NAME
```

This validation catches the misconfiguration at deployment time (during `helm upgrade` or `helm install`) instead of allowing the migration job to fail silently after deployment.

**Who is affected:**

You are affected if you have **any** of the following in your `values.yaml` or `--set` overrides:

```yaml
# Legacy path (deprecated but still supported for backward compatibility)
auth:
  backend:
    migrations:
      image:
        repository: ghcr.io/lerianstudio/casdoor-migrations

# OR new path
caradhras:
  migrations:
    image:
      repository: ghcr.io/lerianstudio/casdoor-migrations
```

**What you need to do:**

If you encounter the validation error during upgrade, follow these steps:

#### Step 1: Check your current values

Inspect your current Helm values to identify any migration image overrides:

```bash
helm get values plugin-access-manager -n plugin-access-manager
```

Look for either of these paths:
- `auth.backend.migrations.image.repository`
- `caradhras.migrations.image.repository`

#### Step 2: Remove or update the override

Choose one of the following options:

**Option 1: Remove the override (recommended)**

If you don't need to pin a specific migration image, remove the override entirely and let the chart use its default (`ghcr.io/lerianstudio/caradhras-migrations`):

```yaml
# Remove these lines from your values.yaml:
# auth:
#   backend:
#     migrations:
#       image:
#         repository: ghcr.io/lerianstudio/casdoor-migrations

# OR remove:
# caradhras:
#   migrations:
#     image:
#       repository: ghcr.io/lerianstudio/casdoor-migrations
```

**Option 2: Update to the correct image**

If you need to explicitly set the migration image, update it to use `caradhras-migrations`:

```yaml
caradhras:
  migrations:
    image:
      repository: ghcr.io/lerianstudio/caradhras-migrations
```

> **Important:** The `caradhras-migrations` image is **not** a downgrade from `casdoor:3.1.0`. It is a different product line (version 1.2.x) specifically designed for the v9.x chart's environment variable schema.

#### Step 3: Clear any legacy overrides

If you have both the old and new paths set, ensure you clear the legacy path:

```yaml
# Clear this if present:
auth:
  backend:
    migrations:
      image:
        repository: ""  # or remove the entire block

# Keep only this:
caradhras:
  migrations:
    image:
      repository: ghcr.io/lerianstudio/caradhras-migrations
```

> **Note:** If you don't have any migration image overrides in your values, this change has no impact on your deployment. The chart will continue using the correct default image.

**Error message reference:**

If the validation fails, you will see an error similar to:

```
Error: INSTALLATION FAILED: template: plugin-access-manager/templates/caradhras/migrations-job.yaml:X:X: executing "plugin-access-manager/templates/caradhras/migrations-job.yaml" at <include "caradhras.migrationsImageRepository" .>: error calling include: template: plugin-access-manager/templates/_helpers.tpl:236:5: executing "caradhras.migrationsImageRepository" at <fail ...>:

plugin-access-manager: the migration image repository resolves to "ghcr.io/lerianstudio/casdoor-migrations", which points at the OLD casdoor-migrations image.
On v9.x the migration Job injects POSTGRES_* env vars, but casdoor-migrations reads DB_* and will fail at runtime with:
  Missing required environment variables: DB_USER, DB_PASS, DB_HOST, DB_NAME
It is NOT a downgrade of casdoor:3.1.0 — caradhras-migrations 1.2.x is a different product line.
Set caradhras.migrations.image.repository to ghcr.io/lerianstudio/caradhras-migrations (or leave it empty to accept the default),
and clear any legacy auth.backend.migrations.image.repository override.
See docs/UPGRADE-8.6-to-9.2.md (Known Gotchas).
```

This error is intentional and prevents a broken deployment. Follow the steps above to resolve it.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.4 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.4 -n plugin-access-manager
```
