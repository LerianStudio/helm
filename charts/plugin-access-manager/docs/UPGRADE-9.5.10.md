# Helm Upgrade from v9.5.9 to v9.5.10

# Topics

- **[Updates](#updates)**
  - [1. Caradhras Backend Image Update](#1-caradhras-backend-image-update)
  - [2. Caradhras UI Image Update](#2-caradhras-ui-image-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Updates

### 1. Caradhras Backend Image Update

The caradhras backend service and its database migrations have been updated from version 1.3.2 to 1.4.0.

**What changed:**

| Component | v9.5.9 | v9.5.10 |
|-----------|--------|---------|
| Caradhras backend image tag | 1.3.2 | 1.4.0 |
| Caradhras migrations image tag | 1.3.2 | 1.4.0 |
| Default tag in template helpers | 1.3.2 | 1.4.0 |

**values.yaml changes:**

**Before (v9.5.9):**

```yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.3.2"
  
  migrations:
    image:
      pullPolicy: ""
      # -- otherwise defaults to 1.3.2 in templates/_helpers.tpl.
      tag: ""
```

**After (v9.5.10):**

```yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.4.0"
  
  migrations:
    image:
      pullPolicy: ""
      # -- otherwise defaults to 1.4.0 in templates/_helpers.tpl.
      tag: ""
```

**Template helper changes:**

**Before (v9.5.9):**

```yaml
{{- define "caradhras.imageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.tag "oldVal" (dig "backend" "image" "tag" "" .Values.auth) "default" "1.3.2") -}}
{{- end }}

{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.3.2") -}}
{{- end }}
```

**After (v9.5.10):**

```yaml
{{- define "caradhras.imageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.tag "oldVal" (dig "backend" "image" "tag" "" .Values.auth) "default" "1.4.0") -}}
{{- end }}

{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.4.0") -}}
{{- end }}
```

**Why this matters:**

This is a minor version update to the caradhras backend service. The update includes:

- Bug fixes and improvements in the caradhras application
- Potential database schema changes handled by the migrations init container
- Updated dependencies and security patches

**What this means for operators:**

- **No configuration changes required** — the upgrade will automatically pull the new image version
- The caradhras deployment will perform a rolling update to the new version
- Database migrations (if any) will run automatically in the init container before each new pod starts
- The migration uses an advisory lock to serialize concurrent executions, so multiple replicas can safely roll out

**Operational impact:**

1. **Image pull**: The upgrade will pull `ghcr.io/lerianstudio/caradhras:1.4.0` and `ghcr.io/lerianstudio/caradhras-migrations:1.4.0` from the registry. Ensure your cluster has network access to `ghcr.io`.

2. **Rolling update**: The caradhras deployment uses `maxSurge: 1` and `maxUnavailable: 0` (as of v9.5.4), ensuring zero-downtime during the upgrade. New pods will start with the 1.4.0 image while old pods continue serving traffic.

3. **Migration execution**: Each new pod runs the `migrate` init container before starting. If the 1.4.0 release includes schema changes, they will be applied during the first pod's init phase. Subsequent pods will see the schema is current and skip migration.

4. **Startup time**: Migration time (if any) does not count against readiness probe timeouts. The caradhras container only starts after the migrate init container completes successfully.

> **Note:** If you have explicitly overridden `caradhras.image.tag` or `caradhras.migrations.image.tag` in your `values.yaml`, those overrides will take precedence. Remove them to use the new default 1.4.0 version, or update them to match.

> **Important:** If the migration fails, the new pod will remain in `Init:CrashLoopBackOff` and the old pod will continue serving traffic. Check the `migrate` init container logs if the rollout does not progress:
>
> ```bash
> kubectl logs deployment/<release>-caradhras -c migrate -n <namespace>
> ```

### 2. Caradhras UI Image Update

The caradhras UI (SPA console) has been updated from version 1.2.0 to 1.4.0.

**What changed:**

| Component | v9.5.9 | v9.5.10 |
|-----------|--------|---------|
| Caradhras UI default image tag | 1.2.0 | 1.4.0 |

**Template changes:**

**Before (v9.5.9):**

```yaml
# caradhras/ui-deployment.yaml
spec:
  template:
    spec:
      containers:
        - name: caradhras-ui
          {{- if typeIs "string" $img }}
          image: {{ $img | quote }}
          imagePullPolicy: Always
          {{- else }}
          image: "{{ $img.repository | default "ghcr.io/lerianstudio/caradhras-ui" }}:{{ $img.tag | default "1.2.0" }}"
          imagePullPolicy: {{ $img.pullPolicy | default "Always" }}
          {{- end }}
```

**After (v9.5.10):**

```yaml
# caradhras/ui-deployment.yaml
spec:
  template:
    spec:
      containers:
        - name: caradhras-ui
          {{- if typeIs "string" $img }}
          image: {{ $img | quote }}
          imagePullPolicy: Always
          {{- else }}
          image: "{{ $img.repository | default "ghcr.io/lerianstudio/caradhras-ui" }}:{{ $img.tag | default "1.4.0" }}"
          imagePullPolicy: {{ $img.pullPolicy | default "Always" }}
          {{- end }}
```

**Why this matters:**

The caradhras UI is the web console (SPA) served by nginx that provides the administrative interface for the access manager. This update brings:

- UI improvements and bug fixes
- Compatibility with the caradhras backend 1.4.0 API
- Updated frontend dependencies

**What this means for operators:**

- **No configuration changes required** — the upgrade will automatically pull the new UI version
- The caradhras-ui deployment will perform a rolling update to the new version
- Users may need to refresh their browser to load the new UI assets
- The UI update is coordinated with the backend update to ensure API compatibility

**Operational impact:**

1. **Image pull**: The upgrade will pull `ghcr.io/lerianstudio/caradhras-ui:1.4.0` from the registry.

2. **Rolling update**: The caradhras-ui deployment will roll out new pods with the updated image. The deployment strategy respects your configured `caradhras.ui.deploymentStrategy` (or the default).

3. **Browser cache**: Users with the old UI loaded in their browser will continue to work until they refresh. The new UI is backward-compatible with the backend during the rollout window.

> **Note:** If you have explicitly set `caradhras.ui.image.tag` in your `values.yaml`, that override will take precedence. Remove it to use the new default 1.4.0 version, or update it to match.

> **Note:** The UI image version has jumped from 1.2.0 to 1.4.0 to align with the backend version. This does not indicate missing releases — the UI and backend are versioned together for compatibility.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.10 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.10 -n plugin-access-manager
```
