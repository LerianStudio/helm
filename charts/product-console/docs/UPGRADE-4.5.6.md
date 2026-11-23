<!-- {% raw %} -->
# Helm Upgrade from v4.5.5 to v4.5.6

## Topics

- **[Overview](#overview)**
- **[Application Version Update](#application-version-update)**
- **[Startup, backup and recovery prerequisites](#startup-backup-and-recovery-prerequisites)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates the application version from `3.5.0` to `3.6.0`. The chart includes a minor formatting change to the MongoDB configuration without changing chart value keys. The application startup and data-recovery prerequisites below still apply; unchanged chart keys do not establish a safe application upgrade.

| Field | v4.5.5 | v4.5.6 |
|-------|--------|--------|
| Chart version | `4.5.5` | `4.5.6` |
| App version | `3.5.0` | `3.6.0` |
| Image tag (default) | `3.5.0` | `3.6.0` |

## Application Version Update

The default container image tag has been updated to match the new application version.

| Setting | v4.5.5 | v4.5.6 |
|---------|--------|--------|
| `image.tag` | `"3.5.0"` | `"3.6.0"` |
| `appVersion` | `"3.5.0"` | `"3.6.0"` |

**What changed:**

The chart now deploys `product-console:3.6.0` by default. If you have explicitly set `image.tag` in your values override file, you may want to update it to `3.6.0` or remove the override to use the chart default.

**Example override (if you want to pin the version explicitly):**

```yaml
image:
  tag: "3.6.0"
```

> **Note:** The chart defaults to a rolling update. Even with `image.tag` retained at `3.5.0`, the Console pod-template application-version label changes and triggers a rollout; the label is not proof that the pod runs `3.6.0`. Adopting `3.6.0` changes both the main container and public-files init-container images. The unchanged bundled MongoDB pod template does not itself trigger a database rollout when the same complete values and stable credentials are retained. Ensure your selected images are available in your configured registry.

**MongoDB configuration formatting:**

A cosmetic formatting change was applied to the `mongodb.auth.existingSecret` field. The YAML string was reformatted across multiple lines for readability, but the rendered template output remains identical. No action is required.

**Before (v4.5.5):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'
```

**After (v4.5.6):**

```yaml
mongodb:
  auth:
    existingSecret: '{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname"
      . }}{{ end }}'
```

This change has no operational impact and does not affect the MongoDB secret configuration.

## Startup, backup and recovery prerequisites

Console `3.6.0`, like `3.5.0`, refuses an empty or whitespace-only `LICENSE_KEY` at startup and requires a valid license for business operations. Preserve the key through your protected Secret mechanism (`secrets.LICENSE_KEY`, or `LICENSE_KEY` in the Secret selected by `useExistingSecret` and `existingSecretName`); do not put real credentials in Git, pasted commands or logs. Preserve `NEXTAUTH_SECRET`, MongoDB credentials and the other required authentication settings. Production startup also refuses `MOCK_MODE=true` or both `PLUGIN_AUTH_ENABLED` and `OAUTH_ENABLED` unset/not `"true"`.

After MongoDB connection validation, each new Console `3.6.0` process asynchronously attempts to drop the legacy MongoDB `license_files` collection. This behavior is inherited from `3.5.0`, not introduced by this patch. A retained `3.5.0` image pin does not avoid the cleanup when the chart restarts its pods.

Before rollout, take a consistent private MongoDB backup and preserve protected release/configuration backups and Secret references. Test recovery in an isolated environment, including the legacy collection if needed; do not proceed without a tested recovery plan. Helm rollback restores release configuration, **not deleted database data**. Before restoring, stop every Console process running a cleanup-capable image. Restarting `3.5.0` or `3.6.0` can delete a restored `license_files` collection again; select an image/configuration independently proven to preserve the restored data before resuming traffic. Do not treat a rollback to chart `4.5.5` as a data-recovery procedure.

Prepare and review a **complete intended configuration** before previewing or upgrading:

```bash
umask 077
helm get values product-console -n product-console -o yaml > current-values.private.yaml
```

Treat the export as sensitive; do not commit, upload or paste it. Prepare `intended-values.private.yaml` from the export and your deployment configuration, preserving all unrelated overrides, datastore/storage settings, credentials and external Secret references. Set `image.tag: "3.6.0"` there to adopt the target image, or deliberately retain your chosen pin and validate that image's own requirements. The image-only fragment above is **not** a complete values file.

Both commands below use `--reset-values -f intended-values.private.yaml`; every omitted setting reverts to the target chart defaults. Review the full file and rendered diff before proceeding. Keep actual MongoDB passwords stable and private for bundled-database upgrade previews; client-side rendering cannot resolve cluster `lookup` and is not a credential-rotation procedure. If `global.externalMongoDefinitions.enabled` is retained, its unchanged post-install/post-upgrade bootstrap hook runs again and can update the MongoDB user's password and replace its roles; preserve the intended credentials and roles and plan for that side effect. Successful hook Jobs are deleted, so do not require a retained completed Job as proof. Securely dispose of temporary exports under your retention policy while retaining recovery backups privately.

The commands assume release `product-console` in namespace `product-console` with no fullname/namespace override. Adapt them to the existing release, not a new namespace or data volume. After upgrade, wait for the Console rollout and verify **all** selected pods' images, then exercise authentication and the Mongo-backed workflows you use; an HTTP health response or a rendered manifest is not a license/business-readiness test:

```bash
kubectl rollout status deployment/product-console -n product-console
kubectl get pods -n product-console -l app.kubernetes.io/name=product-console,app.kubernetes.io/instance=product-console -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'
```

These source and render checks do not constitute a real cluster upgrade, application boot or tested backup/restore.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.6 --reset-values -f intended-values.private.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm -n product-console --version 4.5.6 --reset-values -f intended-values.private.yaml
```
<!-- {% endraw %} -->
