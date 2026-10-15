# Helm Upgrade from v9.5.0 to v9.5.1

# Topics

- **[Fixes](#fixes)**
  - [1. Caradhras Image Version Update](#1-caradhras-image-version-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Caradhras Image Version Update

**What changed:**

The default image tags for the Caradhras backend server and migrations have been updated from `1.2.0` to `1.3.2`. This update also includes clarified documentation about the backward-compatibility mechanism for operators who have overridden legacy `auth.backend.*` configuration paths.

| Setting | v9.5.0 | v9.5.1 |
|---------|--------|--------|
| Default Caradhras server image tag | `1.2.0` | `1.3.2` |
| Default Caradhras migrations image tag | `1.2.0` | `1.3.2` |

**Before (v9.5.0):**

```yaml
# values.yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.2.0"
  migrations:
    image:
      repository: ""
      pullPolicy: ""
      tag: ""
```

```yaml
# templates/_helpers.tpl
{{- define "caradhras.imageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.tag "oldVal" (dig "backend" "image" "tag" "" .Values.auth) "default" "1.2.0") -}}
{{- end }}

{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.2.0") -}}
{{- end }}
```

**After (v9.5.1):**

```yaml
# values.yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.3.2"
  migrations:
    image:
      repository: ""
      pullPolicy: ""
      tag: ""
```

```yaml
# templates/_helpers.tpl
{{- define "caradhras.imageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.tag "oldVal" (dig "backend" "image" "tag" "" .Values.auth) "default" "1.3.2") -}}
{{- end }}

{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.3.2") -}}
{{- end }}
```

**Why this matters:**

- **Bug fixes and improvements:** The `1.3.2` release includes fixes and enhancements from the `1.2.0` baseline
- **Synchronized versions:** Both the server and migrations images are updated to the same version to ensure schema compatibility
- **Database migrations:** The migrations Job will run the `1.3.2` migration set, which may include schema changes required by the new server version

**Operational impact:**

- If you have not explicitly overridden `caradhras.image.tag` or `caradhras.migrations.image.tag` in your `values.yaml`, the upgrade will automatically use the new `1.3.2` images for both the server Deployment and migrations Job
- If you have pinned specific image tags via `caradhras.image.tag` or `caradhras.migrations.image.tag`, your overrides will continue to take precedence
- If you have legacy overrides at `auth.backend.image.tag` or `auth.backend.migrations.image.tag`, those will continue to work due to the backward-compatibility fallback mechanism

**What operators need to do:**

No action required for most deployments. The image version update is automatic and backward-compatible.

> **Important:** The Caradhras migrations Job runs automatically during the Helm upgrade (as a pre-upgrade hook). Ensure your database is backed up before upgrading, especially in production environments.

> **Note:** If you have explicitly pinned `caradhras.image.tag` or `caradhras.migrations.image.tag` to `1.2.0` in your values overrides, you should update both to `1.3.2` to benefit from the latest fixes. The server and migrations versions should always match.

**Example: Pinning both server and migrations to a specific version**

If you need to pin a different version or want to explicitly set both images:

```yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    tag: "1.3.2"
    pullPolicy: Always
  migrations:
    image:
      repository: ghcr.io/lerianstudio/caradhras-migrations
      tag: "1.3.2"
      pullPolicy: Always
```

**Documentation improvements:**

The `values.yaml` comments have been clarified to better explain the backward-compatibility mechanism:

- Server image fields (`caradhras.image.*`) are now explicit in `values.yaml` and take precedence over legacy `auth.backend.image.*` paths
- Migrations image fields (`caradhras.migrations.image.*`) remain empty by default to preserve legacy overrides at `auth.backend.migrations.image.*`
- The helper template comments now emphasize that migrations image fields stay empty to keep legacy overrides visible and prevent silent migration chain errors

> **Note:** If you are still using the legacy `auth.backend.*` configuration paths, they will continue to work. However, the recommended approach is to migrate to the `caradhras.*` paths for clarity and forward compatibility.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.1 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.1 -n plugin-access-manager
```
