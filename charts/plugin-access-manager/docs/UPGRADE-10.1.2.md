<!-- {% raw %} -->
# Helm Upgrade from v10.1.1 to v10.1.2

# Topics

- **[Overview](#overview)**
- **[Before you upgrade](#before-you-upgrade)**
  - [Pinned image tags](#pinned-image-tags)
  - [Service credentials in single-tenant](#service-credentials-in-single-tenant)
- **[Application Version Updates](#application-version-updates)**
  - [1. Identity Service Update (3.13.1 → 3.14.0)](#1-identity-service-update-3131--3140)
  - [2. Auth Service Update (3.13.1 → 3.14.0)](#2-auth-service-update-3131--3140)
  - [3. Caradhras Service Update (1.8.5 → 1.8.6)](#3-caradhras-service-update-185--186)
  - [4. Init User Job Image Update (3.13.1 → 3.14.0)](#4-init-user-job-image-update-3131--3140)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This release updates the application from `3.13.1` to `3.14.0` and Caradhras from `1.8.5` to `1.8.6`. The chart templates change only in default image tags. The chart adds no new values and no new environment variables.

| Component | v10.1.1 | v10.1.2 |
|-----------|---------|---------|
| Chart version | 10.1.1 | 10.1.2 |
| App version | 3.13.1 | 3.14.0 |
| `identity.image.tag` | `3.13.1` | `3.14.0` |
| `auth.image.tag` | `3.13.1` | `3.14.0` |
| `caradhras.image.tag` (default) | `1.8.5` | `1.8.6` |
| `caradhras.migrations.image.tag` (default) | `1.8.5` | `1.8.6` |
| Auth init user image tag (default) | `3.13.1` | `3.14.0` |

**No database migration.** The application `3.14.0` and Caradhras `1.8.6` add no migration over `3.13.1` and `1.8.5`. The `migrate` init container runs, finds the schema and RBAC chains at their head, and does nothing. Caradhras `1.8.6` is a code fix only: it counts the reserved partner role in the partner ceiling.

**Coming from an older chart.** This release adds no schema change of its own. If you come from v10.1.0 or earlier, the v10.1.1 guide applies to you first: it describes a one-way database migration.

# Before you upgrade

### Pinned image tags

A tag in your own values overrides the chart default, and the upgrade does not change it. Check your values:

```bash
helm get values plugin-access-manager -n plugin-access-manager -o yaml
```

```yaml
identity:
  image:
    tag: "..."
auth:
  image:
    tag: "..."
  initUser:
    image:
      tag: "..."
caradhras:
  image:
    tag: "..."
  migrations:
    image:
      tag: "..."
```

Caradhras also reads the legacy keys `auth.backend.image.tag` and `auth.backend.migrations.image.tag`, if the `caradhras.*` tag is empty. Remove an old pin, or move it to `3.14.0` and `1.8.6`. Keep the Caradhras image and the migrations image on the same version.

### Service credentials in single-tenant

Identity `3.14.0` changes how single-tenant installs issue and bind the credentials that Lerian services use to call each other. Each calling service can now get its own credential lane. Before, every credential issued for a target product held every service role of that product. A credential issued for `lender` also held the role for `streaming-hub`, for example.

How it works now:

- A target product that declares the role `service-{caller}` in `m2m.service_roles` gets a separate lane for that caller: `{target}-service-m2m-permission` is split into `{target}-service-{caller}-m2m-permission`. The lane holds that role alone, and the credential is displayed as `{target}-service-{caller}`.
- A caller without its own role stays on the shared lane `{target}-service-m2m-permission`, with the other service roles of the target, displayed as `{target}-service`.
- The split happens when a product publishes its permission declaration. The Identity reconciler version changes in `3.14.0`, so the next publish of each product re-applies its declaration once, and its lanes split and get marked then. When a product starts to declare `service-{caller}`, Identity moves the existing credentials of that caller to the new lane on the next re-apply.
- Every lane carries the machine mark. Adding a role to a lane, or a lane to a user, is refused with `422 IDE-1061`.

What operators must do:

- **Issuing a credential can now return `422`.** `POST /v1/applications/service-credentials` answers `422` and creates nothing when the target has no service lane yet (no `m2m.service_roles`, or a declaration not published), or when its lane gives the `source` service no role. Check the target's declaration before you issue the credential.
- **A caller that moves to its own lane can get `403` until the credential is moved or reissued.** Identity moves the credentials of a caller to its new lane on the next re-apply. If a service gets `403` after the change, check the credential's display name and lane, and issue a new credential if it is still on the wrong lane. To rotate, issue the new credential, deploy it, then revoke the old one with `DELETE /v1/applications/{id}`.
- **Multi-tenant installs are not affected.** In multi-tenant, the Tenant Manager issues service credentials, and `POST /v1/applications/service-credentials` answers `501`. In the Tenant Manager lanes (`runtime-managed:tenant-manager-m2m:service`), adding or removing a role by hand answers `422 IDE-1066`.

Other behavior changes in `3.14.0` that you can notice:

- Identity refuses permissions on a machine role (`422 IDE-1061`), and an empty `m2m.roles: []` admits no machine role. Before, it admitted every declared role.
- Identity refuses the `bancarizador` nature on a partner application.
- Auth refuses password sign-in for a person who has a passkey. Passkey sign-in, a tenant passkey option, and an administrator removing another person's passkey are new.
- Auth refuses a platform organization refresh token, and starts the platform organization SSO with its own callback.
- Identity can extend the application catalog per installation.

# Application Version Updates

### 1. Identity Service Update (3.13.1 → 3.14.0)

**What changed:**

| Setting | v10.1.1 | v10.1.2 |
|---------|---------|---------|
| `identity.image.tag` | `3.13.1` | `3.14.0` |

**Before (v10.1.1):**

```yaml
identity:
  image:
    repository: ghcr.io/lerianstudio/plugin-identity
    pullPolicy: Always
    tag: "3.13.1"
```

**After (v10.1.2):**

```yaml
identity:
  image:
    repository: ghcr.io/lerianstudio/plugin-identity
    pullPolicy: Always
    tag: "3.14.0"
```

**What this means for operators:**

- The default tag changes with the upgrade, and the identity pods roll out with the new image.
- The image name is `plugin-identity`. This chart does not reference `midaz-identity`. If you set that name in your values, the pod stays in `ImagePullBackOff`.
- Read [Service credentials in single-tenant](#service-credentials-in-single-tenant) for the behavior change.

### 2. Auth Service Update (3.13.1 → 3.14.0)

**What changed:**

| Setting | v10.1.1 | v10.1.2 |
|---------|---------|---------|
| `auth.image.tag` | `3.13.1` | `3.14.0` |

**Before (v10.1.1):**

```yaml
auth:
  image:
    repository: ghcr.io/lerianstudio/plugin-auth
    pullPolicy: Always
    tag: "3.13.1"
```

**After (v10.1.2):**

```yaml
auth:
  image:
    repository: ghcr.io/lerianstudio/plugin-auth
    pullPolicy: Always
    tag: "3.14.0"
```

**What this means for operators:**

- The default tag changes with the upgrade, and the auth pods roll out with the new image.
- The image name is `plugin-auth`. This chart does not reference `midaz-auth`.
- The chart ships `identity` and `auth` on the same version. Keep them equal if you pin tags.

### 3. Caradhras Service Update (1.8.5 → 1.8.6)

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

The default version in the template helpers follows the new tag:

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

**What this means for operators:**

- The Caradhras pods roll out with the new image. The rolling update uses `maxSurge: 1` and `maxUnavailable: 0`, so a new pod must be ready before an old one stops, also with `replicaCount: 1`.
- The `migrate` init container runs with the `1.8.6` image. It applies no migration, because `1.8.6` embeds the same schema and RBAC chains as `1.8.5`.
- The template helpers still support the legacy `auth.backend` configuration paths.

> **Note:** If you set `caradhras.migrations.image.tag` in your values, keep it equal to the Caradhras service version. If you leave it empty, the chart uses the default for both.

### 4. Init User Job Image Update (3.13.1 → 3.14.0)

The init user job creates the first administrative user. The job is disabled by default (`auth.initUser.enabled: false`).

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

**What this means for operators:**

- **Existing installations:** No effect. The job is a Helm `post-install` hook. It runs on the first `helm install` only, and never on `helm upgrade`.
- **New installations:** With `auth.initUser.enabled: true`, the job uses the `caradhras-user-init:3.14.0` image.
- **Custom image overrides:** If you set `auth.initUser.image`, your override takes precedence.

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
