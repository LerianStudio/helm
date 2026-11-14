<!-- {% raw %} -->
# Helm Upgrade from v11.0.1 to v11.1.0

## Topics

- [Overview](#overview)
- [Changes](#changes)
- [Configuration reference](#configuration-reference)
- [Action required](#action-required)
- [Preview changes before upgrading](#preview-changes-before-upgrading)
- [Command to upgrade](#command-to-upgrade)
- [Verify](#verify)
- [Recovery considerations](#recovery-considerations)

## Overview

This guide covers chart `plugin-access-manager` **11.0.1 → 11.1.0**, not later releases. The chart `appVersion` stays at `3.17.0`.

**Keep `LICENSE_KEY` when using the default Caradhras 2.1.0 image.** This release adds chart wiring for a license file; it does not make that image read the file. Caradhras 2.1.0 uses `lib-license-go/v4` v4.2.2 and its startup requires a nonempty `LICENSE_KEY`. It does not read `LICENSE_FILE_PATH`. A file-only configuration can pass Helm validation but leave the server unable to start.

| Component | 11.0.1 default | 11.1.0 default |
|---|---|---|
| Chart version | 11.0.1 | 11.1.0 |
| Chart appVersion | 3.17.0 | 3.17.0 |
| Auth image | `ghcr.io/lerianstudio/plugin-auth:3.17.0` | unchanged |
| Identity image | `ghcr.io/lerianstudio/plugin-identity:3.17.0` | unchanged |
| Caradhras server | `ghcr.io/lerianstudio/caradhras:2.1.0` | unchanged |
| Caradhras migrations | `ghcr.io/lerianstudio/caradhras-migrations:2.1.0` | unchanged |

The migrations tag follows the Caradhras server tag, without its digest suffix, unless overridden by `caradhras.migrations.image.tag` or the legacy `auth.backend.migrations.image.tag`. Preserve and review existing image overrides; this table describes defaults only.

Existing, working key-based configuration needs no license-format migration. **Expect a rolling update of auth, identity and Caradhras even when values do not change.** Plan for the Caradhras `migrate` init container to run again in replacement pods.

## Changes

### 1. Optional license-file delivery

The new value is disabled by default:

```yaml
caradhras:
  licenseFile:
    existingSecret: ""
```

When nonempty, `caradhras.licenseFile.existingSecret` names a Secret **in the release namespace** containing a key named `license`. The chart projects that key as `/etc/lerian/license/license`, sets `LICENSE_FILE_PATH` to that path, and adds the read-only directory mount `/etc/lerian/license` to both the server container and the `migrate` init container.

The directory mount does not use `subPath`. Kubernetes can propagate Secret updates to such a volume, but that does not establish that an application loads the file, reloads it after rotation, or can rotate without a restart. The chart uses a Kubernetes Secret volume, not a CSI volume configuration.

**Application compatibility is separate from Helm rendering.** The chart comments describe file mode as requiring an image using `lib-license-go` v5. The shipped Caradhras 2.1.0 server instead uses v4 and accepts the environment key only. No compatible replacement image is identified in this guide. Do not remove the key or change images based solely on the new chart option.

A future file-mode migration needs a specifically verified server image and matching migrations image, their upgrade contract, and a staged startup/rotation test. Merely finding a v5 dependency is not sufficient proof of that contract.

### 2. License environment passed to migrations

In 11.0.1, the chart injects the configured `LICENSE_KEY` into the server only. In 11.1.0 it also passes the key to the `migrate` init container. With file delivery enabled, both receive the file path and mount.

This is **delivery, not a new license gate**. The default `caradhras-migrations:2.1.0` executable (`/postgres-migrations`) does not initialize licensing. It can perform database work before the server checks its license. A successful migration therefore does not prove the server's key is present or valid.

### 3. Validation and rollout behavior

The chart's Caradhras license render check now accepts any of:

- A nonempty `caradhras.secrets.LICENSE_KEY`.
- `caradhras.useExistingSecret: true`.
- A nonempty `caradhras.licenseFile.existingSecret`.

The existing exemption for semantic-version server tags below `2.0.0-0` remains. It is not a recommendation to downgrade. Chart validation cannot validate a license, prove an external Secret exists, or prove a binary supports file mode. With the default 2.1.0 image, retain a valid key issued for the product `caradhras`; the auth/identity license does not license Caradhras.

Even with file delivery disabled, the chart-version label in hashed ConfigMaps/Secrets changes. The pod-template checksums consequently change for auth, identity and Caradhras. In addition, the Caradhras init container gains the license-key environment entry. The conditional mount does **not** make this upgrade restart-free.

## Configuration reference

| Value | Default | Meaning in 11.1.0 |
|---|---|---|
| `caradhras.licenseFile.existingSecret` | `""` | Optional existing Secret with key `license`; enables chart file projection, not application file support. Leave empty with the default image. |
| `caradhras.secrets.LICENSE_KEY` | `""` | Caradhras key in the chart-managed Secret. Retain a valid key for default 2.1.0. |
| `caradhras.useExistingSecret` | `false` | Use an operator-managed Caradhras Secret instead of creating one. |
| `caradhras.existingSecretName` | `""` | Name of that operator-managed Secret. |

With `useExistingSecret: true`, the named Secret must contain `LICENSE_KEY` for Caradhras 2.1.0. When `caradhras.configmap.redisEndpoint` is empty, the deployment also reads `redisEndpoint` from this Secret. Keep all other required Secret keys and current configuration; a license-only replacement Secret may be incomplete.

The existing-Secret selection is not the same option as `licenseFile.existingSecret`: one selects the Caradhras environment Secret, the other a separate optional file Secret.

| Environment variable | Rendered when | Delivery |
|---|---|---|
| `LICENSE_KEY` | Key configured or `useExistingSecret` true | `secretKeyRef` to key `LICENSE_KEY`; server and `migrate` in 11.1.0 |
| `LICENSE_FILE_PATH` | `licenseFile.existingSecret` nonempty | Literal `/etc/lerian/license/license`; server and `migrate` |

Both entries can render together. Caradhras 2.1.0 still uses `LICENSE_KEY`; it does not choose whichever method it finds first. No file/key precedence is asserted for other images.

## Action required

The commands use release name `plugin-access-manager` and namespace `midaz-plugins`. Set these to the actual installed release before running them. You need Helm, kubectl, access to the cluster and the published chart, and permission to read the release. Review backups, capacity and your maintenance window before the rolling update.

1. Save the release's **user-supplied** values to a protected local file. It may contain license keys and other credentials. Do not commit it, attach it to tickets, or publish its contents. Preserve operator-managed Secrets separately through your normal secret-management process.

   ```bash
   RELEASE=plugin-access-manager
   NAMESPACE=midaz-plugins
   umask 077
   VALUES_DIR=$(mktemp -d)
   VALUES_FILE="$VALUES_DIR/am-values.yaml"
   helm get values "$RELEASE" -n "$NAMESPACE" -o yaml > "$VALUES_FILE"
   ```

2. Review the file against your current configuration. Preserve all user overrides (including image repositories/tags, database, authorizer, TLS, resource and secret settings). If Helm returns `null` because there are no user overrides, use an empty YAML mapping (`{}`) as the starting file, then add the required configuration. Do not blindly export `--all` and freeze every old chart default.

3. For default Caradhras 2.1.0, retain the working `caradhras.secrets.LICENSE_KEY` or `caradhras.useExistingSecret`/`existingSecretName` setup. Leave `caradhras.licenseFile.existingSecret` empty. Do not paste a new `caradhras:` block over an existing one: merge keys into the existing mapping without duplicate keys. Auth and identity still need their existing license and authorizer credentials.

4. If recovering from an attempted file-only configuration on 2.1.0, restore a valid Caradhras key using the original Secret mechanism before upgrading. A file mount alone is not a recovery. Review the `migrate` logs and database state if a previous attempt ran migrations; do not assume failure to start meant nothing changed.

5. Take or verify a recent database backup using your normal PostgreSQL procedure and confirm your restore procedure is available. This chart bump does not change the default application or migrations images, but replacement Caradhras pods run the init migrator. Existing image overrides may have a different migration impact.

## Preview changes before upgrading

Use the same complete user-values file for preview and upgrade. A partial file can lose stored overrides; editing a local file without passing `-f` does not apply it. Do not replace this with an isolated `--set` command that drops other release values.

The preview requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install a reviewed plugin version through your normal tooling process. Diff output may expose credentials depending on plugin settings: use Secret suppression and protect the output. ConfigMaps may also contain sensitive operator settings.

```bash
helm diff upgrade "$RELEASE" oci://ghcr.io/lerianstudio/plugin-access-manager \
  --version 11.1.0 -n "$NAMESPACE" -f "$VALUES_FILE" --suppress-secrets
```

Check the rendered image names, Secret references, database settings and expected pod-template changes. A successful preview does not validate application startup or the license.

## Command to upgrade

Run only after reviewing the preview. The values file must still contain all intended user overrides.

```bash
helm upgrade "$RELEASE" oci://ghcr.io/lerianstudio/plugin-access-manager \
  --version 11.1.0 -n "$NAMESPACE" -f "$VALUES_FILE" \
  --wait --timeout 15m
```

Choose a timeout appropriate to your environment. A timeout is not a rollback and does not undo database writes. Keep the protected values/backup artifacts according to your retention policy and securely remove unnecessary local copies afterward.

## Verify

With the example release name and no fullname overrides, the deployments are `plugin-access-manager-auth`, `plugin-access-manager-identity` and `plugin-access-manager-caradhras`. If you override names, use the actual rendered deployment names in the rollout commands.

```bash
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE"
kubectl rollout status "deployment/${RELEASE}-auth" -n "$NAMESPACE" --timeout=15m
kubectl rollout status "deployment/${RELEASE}-identity" -n "$NAMESPACE" --timeout=15m
kubectl rollout status "deployment/${RELEASE}-caradhras" -n "$NAMESPACE" --timeout=15m
helm status "$RELEASE" -n "$NAMESPACE"
```

Confirm the release reports `deployed`, the new pods are ready, and the expected images are running. Verify the init migrator completed and run your normal authentication and identity smoke tests. Ready pods and a deployed Helm status alone are not an end-to-end test.

For the example naming, inspect the migration log after old Caradhras pods have terminated, so the deployment selector does not return an old pod's log:

```bash
kubectl logs "deployment/${RELEASE}-caradhras" -n "$NAMESPACE" -c migrate
kubectl get deployment "${RELEASE}-caradhras" -n "$NAMESPACE" \
  -o jsonpath='{range .spec.template.spec.initContainers[*]}{.name}{"="}{.image}{"\n"}{end}{range .spec.template.spec.containers[*]}{.name}{"="}{.image}{"\n"}{end}'
```

Treat logs as potentially sensitive. Do not print license Secret values to check configuration. If you separately test file-delivery wiring with a verified compatible image, inspect its PodSpec for `LICENSE_FILE_PATH`, the `license-file` volume and the read-only directory mounts; that inspection proves wiring only. Do not assume the application image contains a shell or `ls`.

## Recovery considerations

If startup fails, check Kubernetes events, Secret references, the init migrator and server logs without disclosing credentials. Restore a valid Caradhras environment key if it was removed from the default 2.1.0 configuration.

A Helm rollback restores release resources, not database contents. Do not downgrade Caradhras images or assume an older chart undoes migrations. If an image override or failed prior attempt moved the schema, use the backup/restore and application-version recovery procedure appropriate to that exact release before attempting a rollback.
<!-- {% endraw %} -->
