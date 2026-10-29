<!-- {% raw %} -->
# Helm Upgrade from v10.1.1 to v10.1.2

# Topics

- **[Application Version Updates](#application-version-updates)**
  - [1. Identity Service Update (3.13.1 → 3.14.0)](#1-identity-service-update-3131--3140)
  - [2. Auth Service Update (3.13.1 → 3.14.0)](#2-auth-service-update-3131--3140)
  - [3. Caradhras Service Update (1.8.5 → 1.8.6)](#3-caradhras-service-update-185--186)
  - [4. Init User Job Image Update (3.13.1 → 3.14.0)](#4-init-user-job-image-update-3131--3140)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Application Version Updates

This patch release updates the application versions for all services in the plugin-access-manager chart. These updates include bug fixes and improvements from upstream service releases.

### 1. Identity Service Update (3.13.1 → 3.14.0)

The identity service has been updated to version 3.14.0.

**What changed:**

| Setting | v10.1.1 | v10.1.2 |
|---------|---------|---------|
| `identity.image.tag` | `3.13.1` | `3.14.0` |

**Before (v10.1.1):**

```yaml
identity:
  image:
    repository: ghcr.io/lerianstudio/midaz-identity
    pullPolicy: Always
    tag: "3.13.1"
```

**After (v10.1.2):**

```yaml
identity:
  image:
    repository: ghcr.io/lerianstudio/midaz-identity
    pullPolicy: Always
    tag: "3.14.0"
```

**Why this matters:**

The identity service handles authentication and user identity management. This version update includes upstream improvements and bug fixes that enhance service stability and functionality.

**What this means for operators:**

- **No action required:** The image tag is updated automatically during the Helm upgrade
- **Automatic rollout:** Identity pods will be rolled out with the new image version
- **No configuration changes:** All existing identity service configuration remains compatible

### 2. Auth Service Update (3.13.1 → 3.14.0)

The auth service has been updated to version 3.14.0.

**What changed:**

| Setting | v10.1.1 | v10.1.2 |
|---------|---------|---------|
| `auth.image.tag` | `3.13.1` | `3.14.0` |

**Before (v10.1.1):**

```yaml
auth:
  image:
    repository: ghcr.io/lerianstudio/midaz-auth
    pullPolicy: Always
    tag: "3.13.1"
```

**After (v10.1.2):**

```yaml
auth:
  image:
    repository: ghcr.io/lerianstudio/midaz-auth
    pullPolicy: Always
    tag: "3.14.0"
```

**Why this matters:**

The auth service provides authorization and access control functionality. This version update ensures compatibility with the updated identity service and includes upstream improvements.

**What this means for operators:**

- **No action required:** The image tag is updated automatically during the Helm upgrade
- **Automatic rollout:** Auth pods will be rolled out with the new image version
- **No configuration changes:** All existing auth service configuration remains compatible

### 3. Caradhras Service Update (1.8.5 → 1.8.6)

The caradhras service and its migrations have been updated to version 1.8.6.

**What changed:**

| Setting | v10.1.1 | v10.1.2 |
|---------|---------|---------|
| `caradhras.image.tag` | `1.8.5` | `1.8.6` |
| `caradhras.migrations.image.tag` (default) | `1.8.5` | `1.8.6` |

**Before (v10.1.1):**

```yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.8.5"
  migrations:
    image:
      repository: ""
      pullPolicy: ""
      tag: ""  # defaults to 1.8.5
```

**After (v10.1.2):**

```yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.8.6"
  migrations:
    image:
      repository: ""
      pullPolicy: ""
      tag: ""  # defaults to 1.8.6
```

**Template helper changes:**

The default version in the template helpers has been updated to ensure consistency:

**Before (v10.1.1):**

```yaml
{{- define "caradhras.imageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.tag "oldVal" (dig "backend" "image" "tag" "" .Values.auth) "default" "1.8.5") -}}
{{- end }}

{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.8.5") -}}
{{- end }}
```

**After (v10.1.2):**

```yaml
{{- define "caradhras.imageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.tag "oldVal" (dig "backend" "image" "tag" "" .Values.auth) "default" "1.8.6") -}}
{{- end }}

{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.8.6") -}}
{{- end }}
```

**Why this matters:**

Caradhras is the backend service that manages permissions, roles, and groups. The migrations image must match the service version to ensure database schema compatibility. Both the service and migrations containers are updated together to maintain consistency.

**What this means for operators:**

- **No action required:** Both the service and migrations images are updated automatically
- **Automatic rollout:** Caradhras pods will be rolled out with the new image version
- **Migration execution:** The init container will run any new database migrations from version 1.8.6
- **Backward compatibility:** The template helpers maintain support for legacy `auth.backend` configuration paths

> **Note:** If you have explicitly set `caradhras.migrations.image.tag` in your values, ensure it matches the caradhras service version. The chart defaults handle this automatically if the tag is left empty.

### 4. Init User Job Image Update (3.13.1 → 3.14.0)

The init user job, which creates the initial administrative user, has been updated to version 3.14.0.

**What changed:**

| Setting | v10.1.1 | v10.1.2 |
|---------|---------|---------|
| Default init user image tag | `3.13.1` | `3.14.0` |

**Before (v10.1.1):**

```yaml
# auth/init_user.yaml template
{{- if kindIs "string" $initUserImage }}
image: {{ $initUserImage | quote }}
imagePullPolicy: Always
{{- else }}
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.13.1" }}"
imagePullPolicy: {{ $initUserImage.pullPolicy | default "Always" }}
{{- end }}
```

**After (v10.1.2):**

```yaml
# auth/init_user.yaml template
{{- if kindIs "string" $initUserImage }}
image: {{ $initUserImage | quote }}
imagePullPolicy: Always
{{- else }}
image: "{{ $initUserImage.repository | default "ghcr.io/lerianstudio/caradhras-user-init" }}:{{ $initUserImage.tag | default "3.14.0" }}"
imagePullPolicy: {{ $initUserImage.pullPolicy | default "Always" }}
{{- end }}
```

**Why this matters:**

The init user job runs once during installation to create the initial administrative user account. This update ensures the job uses the same version as the auth and identity services it interacts with, maintaining API compatibility.

**What this means for operators:**

- **No action required:** The default image tag is updated automatically
- **Existing installations:** The job only runs during initial installation; existing users are not affected
- **New installations:** Will use the updated 3.14.0 image for user initialization
- **Custom image overrides:** If you have set `auth.initUser.image` in your values, your override will continue to take precedence

> **Note:** This change only affects the default image tag used when `auth.initUser.image.tag` is not explicitly set in your values. If you have customized this setting, review whether you need to update it to match the new service versions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.2 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.2 -n plugin-access-manager
```
<!-- {% endraw %} -->
