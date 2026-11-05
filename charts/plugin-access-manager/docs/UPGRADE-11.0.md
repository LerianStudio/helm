<!-- {% raw %} -->
# Helm Upgrade from v10.5.1 to v11.0.0

# Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. Caradhras Server Image Updated to v2.1.0](#1-caradhras-server-image-updated-to-v210)
  - [2. License Key Now Required for Caradhras 2.x](#2-license-key-now-required-for-caradhras-2x)
  - [3. Migrations Image Tag Now Defaults to Server Tag](#3-migrations-image-tag-now-defaults-to-server-tag)
  - [4. Major Version Mismatch Validation](#4-major-version-mismatch-validation)
- **[Template Changes](#template-changes)**
  - [Pod Label Optimization](#pod-label-optimization)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This is a **major version upgrade** that increments the chart from 10.5.1 to 11.0.0. The primary change is the upgrade of the Caradhras server from v1.8.6 to v2.1.0, which introduces a mandatory license requirement and changes the default behavior for migrations image tagging.

**What this means for operators:**

Caradhras 2.x refuses to boot without a valid license key. If you are upgrading from a deployment that did not set `caradhras.secrets.LICENSE_KEY` or `caradhras.useExistingSecret`, the chart render will now fail with an explicit error before any resources are applied. You must provide the license key before upgrading.

| Component | v10.5.1 | v11.0.0 |
|-----------|---------|---------|
| Chart version | 10.5.1 | 11.0.0 |
| App version | 3.17.0 | 3.17.0 |
| Caradhras image tag | 1.8.6 | 2.1.0 |
| Migrations image tag default | 1.8.6 (hardcoded) | 2.1.0 (follows server tag) |
| License key requirement | Optional (warning only) | **Mandatory** (render fails without it) |

**Action required:**

1. Set `caradhras.secrets.LICENSE_KEY` in your values, or configure `caradhras.useExistingSecret=true` with a Secret that contains the key
2. Review your migrations image tag if you have overridden it — the chart now validates that server and migrations are on the same major version
3. Expect all pods (auth, identity, caradhras, caradhras-ui) to restart during the upgrade due to label changes

# Breaking Changes

## 1. Caradhras Server Image Updated to v2.1.0

**What changed:**

The default Caradhras server image tag has been updated from `1.8.6` to `2.1.0`.

| Setting | v10.5.1 | v11.0.0 |
|---------|---------|---------|
| `caradhras.image.tag` | `"1.8.6"` | `"2.1.0"` |

**Before (v10.5.1):**

```yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "1.8.6"
```

**After (v11.0.0):**

```yaml
caradhras:
  image:
    repository: ghcr.io/lerianstudio/caradhras
    pullPolicy: Always
    tag: "2.1.0"
```

**Why this matters:**

Caradhras 2.x introduces breaking changes in its licensing model and boot behavior. The server will refuse to start without a valid license key (see next section). This is a major version bump in the application, not just the chart.

**Operational impact:**

- Pods will pull a new image during the upgrade
- The new image enforces the license gate at boot time
- If you have overridden `caradhras.image.tag` in your values, you control the version — but the chart now validates that the migrations image matches the server's major version

**What operators need to do:**

If you want to stay on Caradhras 1.x, explicitly set:

```yaml
caradhras:
  image:
    tag: "1.8.6"
```

If you upgrade to 2.x, you **must** provide a license key (see next section).

## 2. License Key Now Required for Caradhras 2.x

**What changed:**

Caradhras 2.x refuses to boot without a valid license key. The chart now fails the render if you are deploying a 2.x image without setting `caradhras.secrets.LICENSE_KEY` or `caradhras.useExistingSecret=true`.

**Before (v10.5.1):**

The license key was optional. Caradhras 1.x would boot without it and log a warning every hour. The chart would render successfully even if `LICENSE_KEY` was empty.

```yaml
caradhras:
  secrets:
    # Optional — Caradhras 1.x boots without it (with warnings)
    LICENSE_KEY: ""
```

**After (v11.0.0):**

The chart detects the Caradhras version from `caradhras.image.tag`. If the tag is a semver >= 2.0.0 and no license key is configured, the render fails with:

```
ERROR: Caradhras refuses to boot without its own license key.
   Set caradhras.secrets.LICENSE_KEY, or set caradhras.useExistingSecret=true with caradhras.existingSecretName naming a Secret that holds LICENSE_KEY.
   The key is issued for the product `caradhras`; the auth and identity key does not license it.
```

The validation logic in `templates/caradhras/deployment.yaml`:

```yaml
{{- $tag := regexReplaceAll "@.*$" (include "caradhras.imageTag" .) "" }}
{{- $licensed := or (.Values.caradhras.secrets | default dict).LICENSE_KEY .Values.caradhras.useExistingSecret }}
{{- if not (or $licensed (and (regexMatch "^v?[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$" $tag) (semverCompare "<2.0.0-0" $tag))) }}
{{- fail "\n\nERROR: Caradhras refuses to boot without its own license key.\n   Set caradhras.secrets.LICENSE_KEY, or set caradhras.useExistingSecret=true with caradhras.existingSecretName naming a Secret that holds LICENSE_KEY.\n   The key is issued for the product `caradhras`; the auth and identity key does not license it.\n" }}
{{- end }}
```

**Why this matters:**

Caradhras 2.x enforces licensing at the application level. Without the key, the pod will crash-loop. The chart prevents this by failing early during `helm upgrade` or `helm install`, before any resources are applied.

**Operational impact:**

- If you are upgrading from 1.x to 2.x and have not set a license key, `helm upgrade` will fail immediately
- If you are staying on 1.x (by overriding the tag), the validation does not trigger
- The license key is issued for the product `caradhras` — the auth and identity license key does not work here

**What operators need to do:**

Choose one of the following options:

#### Option 1: Set the license key in values.yaml

```yaml
caradhras:
  secrets:
    LICENSE_KEY: "your-caradhras-license-key-here"
```

The chart creates a Secret named `plugin-caradhras-secret` (or the value of `caradhras.existingSecretName` if `useExistingSecret` is true) and injects `LICENSE_KEY` as an environment variable.

#### Option 2: Use an existing Secret

If you manage secrets outside Helm:

```yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "my-caradhras-secret"
```

Your Secret must contain a key named `LICENSE_KEY`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-caradhras-secret
  namespace: midaz-plugins
type: Opaque
data:
  LICENSE_KEY: <base64-encoded-license-key>
```

> **Important:** The license key is product-specific. The key issued for `auth` or `identity` does not license Caradhras. Contact Lerian Studio support to obtain a Caradhras license key.

## 3. Migrations Image Tag Now Defaults to Server Tag

**What changed:**

The default migrations image tag has changed from a hardcoded `1.8.6` to dynamically following the server tag (`caradhras.image.tag`), with any `@digest` suffix stripped.

| Setting | v10.5.1 | v11.0.0 |
|---------|---------|---------|
| `caradhras.migrations.image.tag` default | `"1.8.6"` | Follows `caradhras.image.tag` (without digest) |

**Before (v10.5.1):**

The migrations tag defaulted to `1.8.6` in `templates/_helpers.tpl`:

```yaml
{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" "1.8.6") -}}
{{- end }}
```

If you upgraded the server to a newer version but did not explicitly set `caradhras.migrations.image.tag`, the migrations stayed on 1.8.6. This caused schema mismatches and boot failures.

**After (v11.0.0):**

The migrations tag now defaults to the server tag:

```yaml
{{- define "caradhras.migrationsImageTag" -}}
{{- include "caradhras.value" (dict "newVal" .Values.caradhras.migrations.image.tag "oldVal" (dig "backend" "migrations" "image" "tag" "" .Values.auth) "default" (regexReplaceAll "@.*$" (include "caradhras.imageTag" .) "")) -}}
{{- end }}
```

If `caradhras.image.tag` is `2.1.0`, the migrations tag defaults to `2.1.0`. If the server tag includes a digest (e.g., `2.1.0@sha256:abc123`), the digest is stripped from the migrations tag.

**Why this matters:**

Caradhras refuses to boot if the database schema version does not match the server version. The migrations init container must run the same release as the server. Before this change, operators had to remember to set both tags manually. Now the chart keeps them in sync automatically.

**Operational impact:**

- If you have never overridden `caradhras.migrations.image.tag`, the migrations will now automatically upgrade to 2.1.0 when the server upgrades to 2.1.0
- If you have explicitly set `caradhras.migrations.image.tag` in your values, your override is preserved — but the chart now validates that the major versions match (see next section)

**What operators need to do:**

**If you have not overridden the migrations tag:**

No action required. The migrations will automatically follow the server version.

**If you have overridden the migrations tag:**

Review your override. If you are upgrading the server to 2.1.0, ensure the migrations tag is also 2.1.0:

```yaml
caradhras:
  image:
    tag: "2.1.0"
  migrations:
    image:
      tag: "2.1.0"
```

The chart will fail the render if the major versions do not match (see next section).

## 4. Major Version Mismatch Validation

**What changed:**

The chart now validates that the Caradhras server and migrations images are on the same major version. If the tags are valid semver and the major versions differ, the render fails.

**Validation logic in `templates/caradhras/deployment.yaml`:**

```yaml
{{- $semver := "^v?[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$" }}
{{- $migTag := regexReplaceAll "@.*$" (include "caradhras.migrationsImageTag" .) "" }}
{{- if and (regexMatch $semver $tag) (regexMatch $semver $migTag) (ne (regexFind "[0-9]+" $tag) (regexFind "[0-9]+" $migTag)) }}
{{- fail (printf "\n\nERROR: the Caradhras server tag %q and the migrations tag %q are on different major versions.\n   A server refuses a schema that is behind or ahead of its own release.\n   Set caradhras.image.tag and caradhras.migrations.image.tag to the same release (the legacy auth.backend.migrations.image.tag counts as the migrations tag).\n" $tag $migTag) }}
{{- end }}
```

**Why this matters:**

A Caradhras 2.x server cannot boot with a 1.x schema, and a 1.x server cannot boot with a 2.x schema. The validation prevents a common misconfiguration where an operator upgrades the server but forgets to upgrade the migrations (or vice versa).

**Operational impact:**

If you have overridden `caradhras.migrations.image.tag` (or the legacy `auth.backend.migrations.image.tag`) to a different major version than the server, `helm upgrade` will fail with an error message before applying any changes.

**What operators need to do:**

Ensure both tags are on the same major version:

```yaml
caradhras:
  image:
    tag: "2.1.0"
  migrations:
    image:
      tag: "2.1.0"
```

> **Note:** The validation only triggers if both tags are valid semver. If you use a custom tag like `latest` or `dev`, the validation is skipped.

# Template Changes

## Pod Label Optimization

**What changed:**

The `helm.sh/chart` label has been removed from pod labels (but remains on Deployment, Service, and other non-pod resources). This prevents unnecessary pod restarts when only the chart version changes.

**Before (v10.5.1):**

All resources, including pod templates, carried the `helm.sh/chart` label:

```yaml
# templates/_helpers.tpl
{{- define "plugin-caradhras.labels" -}}
helm.sh/chart: {{ include "plugin-caradhras.chart" .context }}
{{ include "plugin-caradhras.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}
```

**After (v11.0.0):**

The label is conditionally excluded from pod templates:

```yaml
# templates/_helpers.tpl
{{- define "plugin-caradhras.labels" -}}
{{ if not .pod }}helm.sh/chart: {{ include "plugin-caradhras.chart" .context }}
{{ end }}{{ include "plugin-caradhras.selectorLabels" (dict "context" .context "name" .name) }}
app.kubernetes.io/version: {{ include "plugin.version" .context }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- end }}
```

Pod templates now pass `.pod=true` when calling the label helper:

```yaml
# templates/caradhras/deployment.yaml
labels:
  {{- include "plugin-caradhras.labels" (dict "context" . "name" .Values.caradhras.name "pod" true) | nindent 8 }}
```

**Why this matters:**

When the `helm.sh/chart` label is present in the pod template, any chart version bump (even a patch release with no functional changes) triggers a pod restart. By removing the label from pods, the chart avoids unnecessary restarts in future patch releases.

**Operational impact:**

**This upgrade (10.5.1 → 11.0.0) will still restart all pods** because:

1. The Caradhras image tag changes from 1.8.6 to 2.1.0
2. The pod template itself changes (the label removal is a template change)

Future patch releases (e.g., 11.0.0 → 11.0.1) that only bump the chart version without changing images or templates will **not** restart pods.

**What operators need to do:**

No action required. This is a transparent optimization. Expect all pods (auth, identity, caradhras, caradhras-ui) to restart during this upgrade.

# Migration Steps

Follow these steps to upgrade from v10.5.1 to v11.0.0:

**Step 1: Obtain a Caradhras license key**

Contact Lerian Studio support to obtain a license key for the product `caradhras`. The auth and identity license key does not work for Caradhras.

**Step 2: Update your values.yaml**

Add the license key to your values:

```yaml
caradhras:
  secrets:
    LICENSE_KEY: "your-caradhras-license-key-here"
```

Or, if you manage secrets externally:

```yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "my-caradhras-secret"
```

**Step 3: Review your migrations image tag (if overridden)**

If you have explicitly set `caradhras.migrations.image.tag` or `auth.backend.migrations.image.tag`, ensure it matches the server version:

```yaml
caradhras:
  image:
    tag: "2.1.0"
  migrations:
    image:
      tag: "2.1.0"
```

If you have not overridden the migrations tag, skip this step — the chart will automatically use 2.1.0.

**Step 4: Preview the changes**

Run `helm diff` to see what will change:

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.0.0
```

**Step 5: Perform the upgrade**

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.0.0
```

**Step 6: Verify the deployment**

Check that all pods are running and healthy:

```bash
kubectl get pods -n midaz-plugins
```

Check the Caradhras logs to confirm it booted successfully with the license key:

```bash
kubectl logs -n midaz-plugins -l app.kubernetes.io/name=caradhras -c caradhras
```

You should see no license-related warnings or errors.

> **Important:** If the upgrade fails with a license key error, verify that the key is correctly set in your Secret and that the Secret is in the same namespace as the deployment.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.0.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.0.0
```
<!-- {% endraw %} -->
