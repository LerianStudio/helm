<!-- {% raw %} -->
# Helm Upgrade from v1.0.2 to v1.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Optional licence file mounting](#1-optional-licence-file-mounting)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Overview

This guide covers the `notifications` chart upgrade from `1.0.2` to `1.1.0`. This is a **minor** release that adds optional chart wiring to mount a signed licence file. The application version (`appVersion: "1.1.0"`) remains unchanged.

> **Default-image limitation:** The API and all three worker images at tag `1.1.0` correspond to application source revision `4e54f5fa19bf95757891d0a02002438914bfde3d`. They use `lib-license-go/v4 v4.2.2`; the shared bootstrap requires a nonempty `LICENSE_KEY` and does not read `LICENSE_FILE_PATH`. The new mount is preparatory wiring, **not a file-only licensing alternative for these images**. Keep `LICENSE_KEY`. No compatible replacement image set is identified by this guide.

No licensing values change is required if you already supply `secrets.LICENSE_KEY` or reference an external Secret containing `LICENSE_KEY` through `secretRef.name`.

With chart-managed configuration and Secrets, all four Deployment pod templates change even with the optional mount disabled: chart-version labels change the checksums embedded in the templates. Expect a rolling replacement of enabled Deployments, not a guarantee of exactly one container restart per pod. External configuration/Secret overrides may change the rendered impact; review the preview for your values.

The existing pre-upgrade migrations hook also runs when `migrations.enabled` is true. Preserve its `DATABASE_URL`, external PostgreSQL, Redis and RabbitMQ settings, encryption keys, and all other current overrides. Retain a tested database backup/recovery procedure before maintenance. A Helm rollback does not reverse database migrations.

## Features

### 1. Optional licence file mounting

When `licenseFile.existingSecret` is nonempty, the chart mounts that existing Secret as a read-only directory at `/etc/lerian/license` on the API and each enabled worker, and sets `LICENSE_FILE_PATH=/etc/lerian/license/license`. The Secret must contain the key `license`.

#### Why this matters

- **Preparatory wiring:** Operators can stage a file mount for a separately verified compatible application version. Staging it does not activate file licensing in the default images.
- **Secret projection:** Mounting the directory without `subPath` permits Kubernetes to eventually update projected Secret content. This is not proof of application consumption or automatic reload.
- **Existing licensing:** Continue using `LICENSE_KEY` with the default `1.1.0` images. Adding the mount does not establish file/key precedence.

#### How it works

The chart adds four helpers in `templates/_helpers.tpl`:

- `notifications.licenseFileSecret`: Returns `licenseFile.existingSecret` when configured.
- `notifications.licenseFileEnv`: Supplies the `LICENSE_FILE_PATH` environment variable.
- `notifications.licenseFileVolumeMount`: Adds the read-only directory mount.
- `notifications.licenseFileVolume`: Adds the Secret volume and projects its `license` key as `license`.

These helpers are applied to the API and all three worker Deployment templates (`worker-email`, `worker-sms`, `worker-webhook`).

**Before (v1.0.2, API excerpt):**

```yaml
# templates/api/deployment.yaml
          {{- with .Values.api.extraEnvVars }}
          env:
            {{- range $key, $value := . }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          {{- end }}
```

**After (v1.1.0, API excerpt):**

```yaml
# templates/api/deployment.yaml
          {{- $licenseEnv := include "notifications.licenseFileEnv" . }}
          {{- if or $licenseEnv .Values.api.extraEnvVars }}
          env:
            {{- with $licenseEnv }}{{ . | nindent 12 }}{{ end }}
            {{- range $key, $value := .Values.api.extraEnvVars }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          {{- end }}
          {{- with (include "notifications.licenseFileVolumeMount" . | trim) }}{{ . | nindent 10 }}{{ end }}
```

The API retains its existing `envFrom` references. Its pod spec also receives the Secret volume. Workers receive the same mount and volume, and inject `LICENSE_FILE_PATH` into their existing `env` lists. Avoid conflicting `LICENSE_FILE_PATH` entries in component `extraEnvVars`.

#### Secret validation changes

Previously, `templates/secrets.yaml` required `secrets.LICENSE_KEY` whenever `secretRef.name` was unset. In `1.1.0`, that requirement is also bypassed when `licenseFile.existingSecret` is set:

```yaml
{{- if not .Values.secretRef.name }}
{{- if not (include "notifications.licenseFileSecret" .) }}
{{- $_ := required "secrets.LICENSE_KEY is required unless licenseFile.existingSecret is set: the api and every worker refuse to boot without a licence. Set it, point secretRef.name at a Secret that carries LICENSE_KEY, or mount a licence file." .Values.secrets.LICENSE_KEY }}
{{- end }}
```

This is a **render-time validation change only**. A successful file-only render does not mean the default application images can start without `LICENSE_KEY`.

#### New environment variable

| Variable | Value | Description |
|----------|-------|-------------|
| `LICENSE_FILE_PATH` | `/etc/lerian/license/license` | Path supplied when a file Secret is configured; not consumed by the default `1.1.0` bootstrap. |

The chart comments describe file mode as requiring an image using lib-license-go v5. The shipped images use v4. Before any future file-only migration, verify the exact API and every enabled worker image, application bootstrap, precedence, file readability and rotation semantics. A library major version or a chart mount alone is insufficient evidence.

## Configuration Reference

### New values

The new value defaults to empty. The comments below clarify the default-image limitation rather than repeating the chart's broader alternative-license wording:

```yaml
licenseFile:
  # Existing Secret containing key `license`; optional preparatory mount.
  # Keep LICENSE_KEY with the default API and worker images at 1.1.0.
  existingSecret: ""
```

| Field | Default | Description |
|-------|---------|-------------|
| `licenseFile.existingSecret` | `""` | Existing file Secret name. Enables mount/env wiring and bypasses chart key validation, but does not remove the default images' runtime requirement for `LICENSE_KEY`. |

### Changed values

The `secrets.LICENSE_KEY` default remains empty. Its chart comment changed from `REQUIRED: licence key; the api and every worker refuse to boot without it.` to `REQUIRED unless licenseFile.existingSecret is set: licence key; the api and every worker refuse to boot without a licence.` Interpret the exception as chart validation behavior, not default-image file support.

`secretRef.name` remains the existing external environment Secret mechanism. If it is used, retain `LICENSE_KEY` and all other required keys there. The file Secret is separate and is not managed by the chart.

## Migration Steps

### Preserve the complete current configuration

The examples use release `notifications` in namespace `notifications`. Change these to match the existing installation. Use the **same complete values file** for preview and upgrade, preserving all current overrides, including values originally passed through `--set` and the existing secret-injection process.

For GitOps-managed installations, update the authoritative configuration through the normal reconciliation process instead of introducing a competing manual Helm upgrade. For manually managed releases, export stored user-supplied values as a starting point:

```bash
RELEASE=notifications
NAMESPACE=notifications
umask 077
VALUES_DIR=$(mktemp -d)
VALUES_FILE="$VALUES_DIR/notifications-upgrade-values.yaml"
helm get values "$RELEASE" -n "$NAMESPACE" -o yaml > "$VALUES_FILE"
```

This file may contain credentials. Protect it and do not commit or publish it. Securely remove unnecessary local copies after the upgrade according to your retention policy. Reconcile it with your authoritative configuration and review target defaults. If no user values were stored, replace a null/empty export with a valid YAML mapping and populate all required configuration. Do not replace the complete file with the small example below or blindly pin every computed old default.

### Option 1: Continue using key-based licensing

Keep `secrets.LICENSE_KEY`, or keep the external Secret referenced by `secretRef.name` with its `LICENSE_KEY` key. Preserve every other override and required key, including encryption keys and the migrations DSN. Leave `licenseFile.existingSecret` empty unless deliberately staging the mount. No licence-format migration is required.

### Option 2: Stage a file mount while retaining the key

This is optional chart preparation, not migration to file-only licensing.

1. Obtain the intended signed licence file through your approved secure process. Create a Secret containing key `license` in the workload namespace. The following example assumes no `namespaceOverride`; if configured, create the Secret in that namespace instead. Replace the example local file path before running:

```bash
kubectl create secret generic notifications-license \
  --from-file=license=/path/to/your/license.lic \
  -n "$NAMESPACE"
```

2. Merge this fragment into the complete file identified by `VALUES_FILE`, keeping the current `LICENSE_KEY` source and all other overrides:

```yaml
licenseFile:
  existingSecret: "notifications-license"
```

3. Preview and upgrade using the commands below. **Do not remove `LICENSE_KEY`** from values or the external Secret with the default images. They do not select a file because `LICENSE_FILE_PATH` is present.

The file Secret must exist before new pods start. Missing Secrets or a missing `license` key can prevent startup. Maintain and rotate the Secret externally. Projection updates are eventual; this guide makes no application reload guarantee and supplies no unverified replacement images.

## Preview changes before upgrading

```bash
helm diff upgrade "$RELEASE" oci://ghcr.io/lerianstudio/notifications-helm \
  --version 1.1.0 -n "$NAMESPACE" -f "$VALUES_FILE"
```

Requires an installed, compatible [helm-diff plugin](https://github.com/databus23/helm-diff); review and pin plugins according to your environment policy. Diff output may contain sensitive configuration; keep it private. Review every change and the migrations hook before proceeding, using the same values and secret resolution process for preview and upgrade.

## Command to upgrade

```bash
helm upgrade "$RELEASE" oci://ghcr.io/lerianstudio/notifications-helm \
  --version 1.1.0 -n "$NAMESPACE" -f "$VALUES_FILE" --wait --timeout 10m
```

Do not run a bare `--set licenseFile.existingSecret=...` upgrade that loses unrelated release overrides. The complete preserved values file is the input to both commands above.

## Verify

Inspect the release and enabled Deployments:

```bash
helm status "$RELEASE" -n "$NAMESPACE"
kubectl get deployments -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE" -o name
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE"
```

Wait for each enabled Deployment using the names returned above. With default names (omit disabled workers and adjust names for overrides):

```bash
kubectl rollout status deployment/notifications -n "$NAMESPACE" --timeout=10m
kubectl rollout status deployment/notifications-worker-email -n "$NAMESPACE" --timeout=10m
kubectl rollout status deployment/notifications-worker-sms -n "$NAMESPACE" --timeout=10m
kubectl rollout status deployment/notifications-worker-webhook -n "$NAMESPACE" --timeout=10m
```

If `namespaceOverride` is set, use that workload namespace for all `kubectl` inspection and rollout commands, while retaining the release namespace for Helm commands.

For a staged file mount, inspect PodSpec wiring without assuming a shell or `ls` exists inside the application image:

```bash
kubectl get deployments -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.spec.containers[*]}{.name}{"\n"}{.env}{"\n"}{.volumeMounts}{"\n"}{end}{.spec.template.spec.volumes}{"\n"}{end}'
```

Each enabled API/worker should have `LICENSE_FILE_PATH=/etc/lerian/license/license`, a read-only `license-file` mount at `/etc/lerian/license`, and a volume referencing the intended Secret and its `license` key, without `subPath`. This verifies configuration only, not application file consumption or licensing success. Confirm readiness and run your established application smoke tests.

The successful migrations hook is normally deleted, so absence alone proves neither failure nor recovery. These instructions have been checked statically; they do not constitute an exercised live upgrade, automatic reload or database restore.
<!-- {% endraw %} -->
