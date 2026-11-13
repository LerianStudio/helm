# Helm Upgrade from v4.5.4 to v4.5.5

## Topics

- **[Overview](#overview)**
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch chart release that updates the default application image from `3.4.0` to `3.5.0`; it does not change chart value keys. This is not a claim that application startup is non-destructive: the license and MongoDB prerequisites below still apply.

| Field | v4.5.4 | v4.5.5 |
|-------|--------|--------|
| Chart version | `4.5.4` | `4.5.5` |
| App version | `3.4.0` | `3.5.0` |
| Default image tag | `3.4.0` | `3.5.0` |

**Key changes:**

- Application version bumped from `3.4.0` to `3.5.0`
- Default `image.tag` updated from `3.4.0` to `3.5.0` to match the new application version

> **Important:** This release updates the application version. Review the product-console application release notes for `3.5.0` to understand what changed in the application itself. This guide covers only the Helm chart configuration changes.

## Configuration Changes

The chart updates the default image tag to match the new application version.

### Image tag configuration

**Before (v4.5.4):**

```yaml
image:
  repository: lerianstudio/product-console
  pullPolicy: IfNotPresent
  tag: "3.4.0"
```

**After (v4.5.5):**

```yaml
image:
  repository: lerianstudio/product-console
  pullPolicy: IfNotPresent
  tag: "3.5.0"
```

**Impact:**

- Operators who did not override `image.tag` in their values will automatically receive the new `3.5.0` image
- Operators who explicitly set `image.tag` in their values override file will continue to use their specified version

| Setting | v4.5.4 | v4.5.5 | Notes |
|---------|--------|--------|-------|
| `image.tag` | `"3.4.0"` | `"3.5.0"` | Now matches `appVersion` |

## Migration Steps

No new chart value keys are required, but application startup and recovery prerequisites are mandatory before starting the target image.

**Startup and data safety:** Console `3.5.0`, like `3.4.0`, requires a nonempty valid `LICENSE_KEY`; configure it through your protected Secret mechanism, not source control or a pasted command. Preserve the other startup credentials, including `NEXTAUTH_SECRET` and MongoDB authentication. After MongoDB connection validation, each new process asynchronously attempts to drop the legacy `license_files` collection. This cleanup is inherited behavior, not newly introduced by `3.5.0`.

Before rollout, take a consistent private MongoDB backup and retain protected release/configuration and Secret references. Validate a recovery procedure in an isolated environment, including recovery of the legacy collection if needed; do not proceed without a tested recovery plan. Helm rollback restores release configuration, not deleted database data. Before restoring data, stop all Console processes running cleanup-capable images; starting `3.4.0` or `3.5.0` again can delete a restored `license_files` collection. Select a recovery image/configuration proven to preserve the restored data before resuming traffic. Neither a real upgrade nor a backup/restore exercise was performed to validate this guide.

**Recommended upgrade process:**

1. **Export values privately and prepare a complete intended configuration**:

```bash
umask 077
helm get values product-console -n product-console -o yaml > current-values.private.yaml
```

Treat this file as sensitive: it may contain credentials. Do not commit, upload or paste it. Prepare `intended-values.private.yaml` from this export and your deployment configuration. Preserve every unrelated override, datastore/storage setting, credential and external Secret reference. Securely dispose of temporary exports after validation under your retention policy; retain recovery backups privately.

2. **Set the intended image explicitly** in `intended-values.private.yaml`: use `image.tag: "3.5.0"` for this target, or deliberately retain a different pin and verify that image's own requirements. Editing a local file alone does not change stored Helm values.

3. **Review the complete intended configuration**. The preview and upgrade below both use `--reset-values -f intended-values.private.yaml`: omitted settings revert to chart defaults, so this must not be a partial image-only fragment. Preserve existing Secret references and all intended custom settings before continuing.

4. **Preview the changes** using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

5. **Run the upgrade command**.

6. **Verify the deployment rolls successfully**:

```bash
kubectl rollout status deployment/product-console -n product-console
```

7. **Confirm the new image is running**:

```bash
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console,app.kubernetes.io/instance=product-console -o jsonpath='{.items[0].spec.containers[0].image}'
```

Expected output: `lerianstudio/product-console:3.5.0` (or your pinned version if you overrode `image.tag`)

> **Note:** This upgrade triggers a rolling restart of the product-console deployment because the image tag changes. Plan the upgrade during a maintenance window if your environment requires zero downtime.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.5 --reset-values -f intended-values.private.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.5 --reset-values -f intended-values.private.yaml
```
