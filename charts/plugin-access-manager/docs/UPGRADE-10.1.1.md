<!-- {% raw %} -->
# Helm Upgrade from v10.1.0 to v10.1.1

# Topics

- **[Fixes](#fixes)**
  - [1. Caradhras Image Version Update](#1-caradhras-image-version-update)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Caradhras Image Version Update

This release updates the Caradhras (auth backend) container images from version `1.5.1` to `1.8.5`. This is a patch-level maintenance update that includes bug fixes and improvements to the Caradhras service.

**What changed:**

The default image tags for both the main Caradhras service and the migrations init container have been updated across the chart:

| Setting | v10.1.0 | v10.1.1 |
|---------|---------|---------|
| `caradhras.image.tag` | `1.5.1` | `1.8.5` |
| `caradhras.migrations.image.tag` (default) | `1.5.1` | `1.8.5` |

**Why this matters:**

The `1.8.5` release of Caradhras includes accumulated bug fixes and stability improvements since `1.5.1`. Upgrading ensures your auth backend benefits from these fixes. The migration image update ensures that database schema migrations run with the same version as the runtime service, maintaining consistency between schema and application code.

**Default behavior:**

If you have not explicitly overridden the image tags in your `values.yaml`, the upgrade will automatically pull and deploy Caradhras `1.8.5`. The chart's default values and template helpers now reference `1.8.5` as the baseline version.

**Before (v10.1.0):**

```yaml
# values.yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.5.1"
  migrations:
    image:
      repository: ""
      pullPolicy: ""
      # Defaults to 1.5.1 in templates/_helpers.tpl
      tag: ""
```

```yaml
# templates/_helpers.tpl
{{- define "caradhras.imageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.tag "oldVal" (dig "backend" "image" "tag" "" .Values.auth) "default" "1.5.1") -}}
{{- end }}

{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.5.1") -}}
{{- end }}
```

**After (v10.1.1):**

```yaml
# values.yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.8.5"
  migrations:
    image:
      repository: ""
      pullPolicy: ""
      # Defaults to 1.8.5 in templates/_helpers.tpl
      tag: ""
```

```yaml
# templates/_helpers.tpl
{{- define "caradhras.imageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.image.tag "oldVal" (dig "backend" "image" "tag" "" .Values.auth) "default" "1.8.5") -}}
{{- end }}

{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.8.5") -}}
{{- end }}
```

**Operational impact:**

When you upgrade to v10.1.1, Kubernetes will perform a rolling update of the Caradhras deployment:

1. The migrations init container runs first with the `1.8.5` image, applying any schema changes
2. The Caradhras pods are then replaced with new pods running `1.8.5`
3. Old pods are terminated only after new pods pass readiness checks

This is a standard rolling update with no expected downtime if your `replicaCount` is greater than 1.

> **Note:** If you have explicitly pinned `caradhras.image.tag` or `caradhras.migrations.image.tag` in your `values.yaml` to `1.5.1` (or any other version), those overrides will continue to take precedence. Review your values file to determine whether you want to adopt the new default or maintain your pin.

> **Important:** The main Caradhras image tag and the migrations image tag should always match. If you override one, override both to the same version to avoid schema/application version skew.

# Migration Steps

This upgrade requires no manual migration steps for most operators. Follow these steps to safely upgrade from v10.1.0 to v10.1.1:

**Step 1: Review your current image configuration**

Check whether you have explicitly overridden the Caradhras image tags:

```bash
helm get values plugin-access-manager -n plugin-access-manager
```

Look for any of these keys in the output:

```yaml
caradhras:
  image:
    tag: "..."
  migrations:
    image:
      tag: "..."
```

**Step 2: Decide on your image version**

Choose one of the following options based on your deployment strategy:

#### Option 1: Adopt the new default (recommended)

If you have **not** overridden the image tags, or if you want to adopt the `1.8.5` update, no action is required. The upgrade will automatically deploy Caradhras `1.8.5`.

#### Option 2: Maintain an explicit pin

If you have explicitly pinned the Caradhras version and want to stay on `1.5.1` (or another version) for now, ensure both the main image and migrations image are pinned to the same version in your `values.yaml`:

```yaml
caradhras:
  image:
    tag: "1.5.1"
  migrations:
    image:
      tag: "1.5.1"
```

> **Warning:** Keeping an older version means you will not receive the bug fixes and improvements included in `1.8.5`. Only pin to an older version if you have a specific compatibility requirement.

**Step 3: Validate your configuration locally**

Test your configuration with a dry-run to ensure the upgrade will succeed:

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 10.1.1 \
  -n plugin-access-manager \
  --dry-run \
  --debug
```

Review the output to confirm the expected image tags are rendered in the Deployment and Job manifests.

**Step 4: Proceed with the upgrade**

Once you have confirmed your configuration, proceed with the upgrade using the command in the [Command to upgrade](#command-to-upgrade) section.

> **Note:** The upgrade performs a rolling update of the Caradhras deployment. If you have `replicaCount: 1`, expect a brief service interruption during pod replacement. For zero-downtime upgrades, ensure `replicaCount` is set to 2 or higher.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.1 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.1.1 -n plugin-access-manager
```
<!-- {% endraw %} -->
