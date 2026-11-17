<!-- {% raw %} -->
# Helm Upgrade from v11.1.2 to v11.2.0

# Topics

- **[Features](#features)**
  - [1. License File Support for Auth and Identity](#1-license-file-support-for-auth-and-identity)
- **[Configuration Reference](#configuration-reference)**
  - [Auth Service License File](#auth-service-license-file)
  - [Identity Service License File](#identity-service-license-file)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. License File Support for Auth and Identity

This release adds chart wiring to mount a signed license file for auth and identity; it does not add file-based licensing support to the default application images. Both v11.1.2 and v11.2.0 default to auth and identity **3.17.0**, built with `lib-license-go/v4 v4.2.2`. Those applications require a nonempty `LICENSE_KEY` at startup and do not consume `LICENSE_FILE_PATH`. **Keep `LICENSE_KEY` for both services with these images; do not perform a file-only migration.** The mounting configuration below describes chart behavior, not runtime support. This guide does not prescribe a compatible replacement image.

**What changed:**

New configuration fields have been added to both services:

```yaml
auth:
  licenseFile:
    existingSecret: ""

identity:
  licenseFile:
    existingSecret: ""
```

**Compatibility and rotation:**

The new mount is opt-in chart infrastructure for independently verified compatible application images. A library major version alone is not proof that an application consumes the file or accepts file-only startup. Kubernetes Secret projection is not evidence that the application reloads a changed license; verify the exact image's rotation/reload behavior separately.

**How it works:**

When `auth.licenseFile.existingSecret` or `identity.licenseFile.existingSecret` is set:

1. The chart mounts the specified Secret as a directory at `/etc/lerian/license`
2. The Secret must contain a key named `license` with the signed license file content
3. The environment variable `LICENSE_FILE_PATH` is automatically set to `/etc/lerian/license/license`
4. For chart-managed Secrets, the template permits omitting `LICENSE_KEY` when a file Secret is configured. This is only a rendering relaxation: the default auth and identity 3.17.0 applications still refuse an empty `LICENSE_KEY`.

**Default behavior:**

Both `existingSecret` fields default to empty strings (`""`), which means:

- The chart continues to use the existing `LICENSE_KEY` environment variable approach
- Keep a nonempty `LICENSE_KEY` in each chart-managed component Secret, or in the external Secret selected through that component's `useExistingSecret` and `existingSecretName`
- No file mounting occurs
- The existing environment-key licensing path is retained; this does not mean a no-rollout upgrade. Rendering the two published releases with identical key-mode values changes auth, identity and Caradhras pod-template checksums.

**Before (v11.1.2):**

```yaml
# auth/secrets.yaml
data:
  LICENSE_KEY: {{ required "auth.secrets.LICENSE_KEY is required: auth refuses to boot without a license. Set it, or use auth.useExistingSecret with a Secret that carries LICENSE_KEY." .Values.auth.secrets.LICENSE_KEY | b64enc | quote }}
```

```yaml
# auth/deployment.yaml - no license file volume or mount
spec:
  template:
    spec:
      containers:
        - name: auth
          env:
            {{- toYaml $h.env | nindent 12 }}
```

**After (v11.2.0):**

```yaml
# auth/secrets.yaml - chart validation relaxed; default application still requires LICENSE_KEY
data:
  {{- if include "plugin-access-manager.licenseFileSecret" .Values.auth }}
  {{- with .Values.auth.secrets.LICENSE_KEY }}
  LICENSE_KEY: {{ . | b64enc | quote }}
  {{- end }}
  {{- else }}
  LICENSE_KEY: {{ required "auth.secrets.LICENSE_KEY is required: auth refuses to boot without a license. Set it, or use auth.useExistingSecret with a Secret that carries LICENSE_KEY." .Values.auth.secrets.LICENSE_KEY | b64enc | quote }}
  {{- end }}
```

```yaml
# auth/deployment.yaml - new license file volume and mount when configured
spec:
  template:
    spec:
      containers:
        - name: auth
          env:
            {{- toYaml $h.env | nindent 12 }}
            {{- with (include "plugin-access-manager.licenseFileEnv" .Values.auth | trim) }}{{ . | nindent 12 }}{{ end }}
          {{- with (include "plugin-access-manager.licenseFileMount" .Values.auth | trim) }}
          volumeMounts:
            {{- . | nindent 12 }}
          {{- end }}
      {{- with (include "plugin-access-manager.licenseFileVolume" .Values.auth | trim) }}
      volumes:
        {{- . | nindent 8 }}
      {{- end }}
```

The same pattern applies to the identity service (`identity/secrets.yaml` and `identity/deployment.yaml`).

**Template helpers added:**

Four new template helpers were added to `_helpers.tpl` to support license file mounting:

- `plugin-access-manager.licenseFileSecret`: Returns the Secret name if configured
- `plugin-access-manager.licenseFileEnv`: Injects `LICENSE_FILE_PATH` environment variable
- `plugin-access-manager.licenseFileMount`: Defines the volume mount at `/etc/lerian/license`
- `plugin-access-manager.licenseFileVolume`: Defines the Secret volume with the `license` key

> **Important:** The shipped auth and identity 3.17.0 images are not file-only compatible. Enabling the mount does not bypass their mandatory `LICENSE_KEY` startup gate. For any separately selected image, verify its exact source and file-only startup behavior before using this wiring; the chart does not validate compatibility.

# Configuration Reference

These fields configure mounts only. They are **not a supported replacement for `LICENSE_KEY` with the default auth and identity 3.17.0 images**.

| Parameter | Default | Chart behavior |
|-----------|---------|----------------|
| `auth.licenseFile.existingSecret` | `""` | Names a pre-existing Secret with key `license`; mounts it read-only at `/etc/lerian/license` and sets `LICENSE_FILE_PATH=/etc/lerian/license/license`. Relaxes the chart-managed Secret's `LICENSE_KEY` rendering requirement, not the application's startup gate. |
| `identity.licenseFile.existingSecret` | `""` | Same chart-only behavior for identity. |

### Auth Service License File

`auth.licenseFile.existingSecret` controls the auth mount described above; keep it empty for the default image and retain auth's existing `LICENSE_KEY`.

### Identity Service License File

`identity.licenseFile.existingSecret` controls the identity mount described above; keep it empty for the default image and retain identity's existing `LICENSE_KEY`.

The chart does not create either file Secret or validate its contents. If a separately verified compatible image is used, its file Secret must exist in the release namespace before rollout. Auth and identity have independent chart settings; that independence does not establish runtime support in either default image.

For the shipped images, leave both file-Secret names empty and preserve the existing licensed environment-key configuration. With `auth.useExistingSecret` or `identity.useExistingSecret`, the selected external Secret must still carry a nonempty `LICENSE_KEY`; adding a file Secret is not a substitute. Preserve all other required keys and Secret references. Do not paste license values or credentials into shell arguments, logs, or shared artifacts.

# Migration Steps

For this historical upgrade from v11.1.2 to v11.2.0, keep environment-key licensing for both default 3.17.0 services. No licensing-format migration is required. A successful Helm render does not prove application startup or license-file consumption.

1. Make private backups of the release values and manifests, and confirm the existing database/data recovery procedure. Release values and rendered Secrets may contain credentials; do not print them to a terminal, CI log, or review comment.
2. Prepare a private `values-upgrade.yaml` containing the **complete intended configuration** for the target release, not just the licensing fragment. Preserve all unrelated overrides, explicit image pins, ingress/TLS, resources, persistence, database settings/current credentials, bootstrap prerequisites, and external Secret references. Retain nonempty `LICENSE_KEY` for both default services, either via chart-managed Secrets or their selected external Secrets. Keep `auth.licenseFile.existingSecret` and `identity.licenseFile.existingSecret` empty. Do not use placeholder credentials from documentation as real values.
3. Use that same file with `--reset-values` in every preview and upgrade below. Resetting deliberately avoids implicit reuse of removed stored overrides; it also discards omitted settings, so review the full intended configuration first. Private value files must not be committed.
4. Plan for auth, identity and Caradhras rollouts even when file mounts remain disabled: the published releases change their pod-template checksums with identical key-mode configuration. Verify readiness and normal authenticated operation after rollout. Do not infer runtime validation from chart tests.

File-only migration is not an upgrade step for the default images in this release. Any future adoption requires separately verified compatible images and their supported license format, startup, rotation, and rollback procedures; no such replacement image is established by this guide.

# Preview changes before upgrading

Use Helm with support for `--dry-run=client` and `--hide-secret`. Confirm the complete private values file before running:

```bash
helm upgrade plugin-access-manager oci://ghcr.io/lerianstudio/plugin-access-manager \
  --version 11.2.0 \
  -n midaz-plugins \
  --reset-values -f values-upgrade.yaml \
  --dry-run=client --hide-secret
```

Secret hiding reduces disclosure but does not guarantee other rendered resources contain no sensitive values. Keep preview output private and do not use `--debug`. Preview validates rendering, not whether referenced Secrets exist or the application starts. Offline upgrade-mode fixtures with the bundled database can require explicit existing database credentials; supply them only through the private intended values/Secret workflow, never decoded-secret diagnostic output.

For a manifest diff, use a compatible [helm-diff plugin](https://github.com/databus23/helm-diff) and suppress Secret output:

```bash
helm diff upgrade plugin-access-manager oci://ghcr.io/lerianstudio/plugin-access-manager \
  --version 11.2.0 \
  -n midaz-plugins \
  --reset-values -f values-upgrade.yaml \
  --suppress-secrets
```

The diff plugin is optional; check its supported flags locally. Keep its output private as other resources can contain sensitive values. Both previews must use the same reviewed complete configuration as the actual upgrade.

# Command to upgrade

After reviewing the preview and confirming backup/recovery and startup prerequisites:

```bash
helm upgrade plugin-access-manager oci://ghcr.io/lerianstudio/plugin-access-manager \
  --version 11.2.0 \
  -n midaz-plugins \
  --reset-values -f values-upgrade.yaml
```
<!-- {% endraw %} -->
