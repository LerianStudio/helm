<!-- {% raw %} -->
# Helm Upgrade from v10.5.1 to v11.0.0

## Topics

- **[Changes](#changes)**
  - [1. Caradhras 2.1.0 is the default](#1-caradhras-210-is-the-default)
  - [2. Caradhras needs its own license key](#2-caradhras-needs-its-own-license-key)
  - [3. Server and migrations tags must share a major version](#3-server-and-migrations-tags-must-share-a-major-version)
  - [4. Pod templates drop the helm.sh/chart label](#4-pod-templates-drop-the-helmshchart-label)
- **[Action required](#action-required)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Changes

### 1. Caradhras 2.1.0 is the default

The default `caradhras.image.tag` changes from `1.8.6` to `2.1.0`. The `auth`, `identity` and `caradhras-ui` images do not change.

The `migrate` init container of the Caradhras pod applies the Caradhras database migrations before the server starts. When `caradhras.migrations.image.tag` and the legacy `auth.backend.migrations.image.tag` are empty, its tag now follows `caradhras.image.tag` without an `@` digest. In v10.5.1, it was always `1.8.6`. A release that sets only `caradhras.image.tag` now migrates with the image of that same release.

> **Warning:** The move to Caradhras 2.x cannot be reversed by Helm alone. The 2.x migrations move the database forward, and a 1.8.x Caradhras pod then refuses to start. A `helm rollback` to v10.5.1 alone does not bring Caradhras 1.8.6 back. To go back, restore a database backup taken right before the upgrade, and roll the release back to v10.5.1.

`auth.initUser.enabled: true` needs identity `3.17.0` or later, and Caradhras server and migrations tags `2.1.0` or later, as stable versions: no prerelease suffix and no `@` digest. In v10.5.1, the default Caradhras tag `1.8.6` failed this check. With the v11.0.0 defaults, the check passes. The setting still needs a Caradhras license key and its own values, such as `auth.initUser.adminPassword`.

### 2. Caradhras needs its own license key

Caradhras 2.x refuses to boot without a license key issued for the product `caradhras`. The license key of `auth` and `identity` does not license it.

In v10.5.1, the chart added the `LICENSE_KEY` env to Caradhras only when a key was set or `caradhras.useExistingSecret` was `true`, and rendered without one. In v11.0.0, the render fails without `caradhras.secrets.LICENSE_KEY` or `caradhras.useExistingSecret: true`:

```text
ERROR: Caradhras refuses to boot without its own license key.
   Set caradhras.secrets.LICENSE_KEY, or set caradhras.useExistingSecret=true with caradhras.existingSecretName naming a Secret that holds LICENSE_KEY.
   The key is issued for the product `caradhras`; the auth and identity key does not license it.
```

The only exception is a `caradhras.image.tag` that is a semantic version below `2.0.0`, for example `1.8.6`. A `2.0.0` prerelease, `latest` and a bare digest need the key. For a tag with a digest suffix, such as `2.1.0@sha256:...`, the chart reads the version before the `@`.

The chart cannot check the key itself. The `migrate` init container needs no key and moves the database to 2.x before the server reads the key. A missing or wrong key therefore stops the 2.x server only after the database has moved. A key issued for another product has the same result.

With `caradhras.useExistingSecret: true`, the chart creates no Caradhras Secret. The Caradhras pod reads `LICENSE_KEY` from the Secret that `caradhras.existingSecretName` names. A Secret without the `LICENSE_KEY` key renders, and the Caradhras 2.x pod then refuses to boot. When `caradhras.configmap.redisEndpoint` is empty, the pod also reads the session store endpoint from the `redisEndpoint` key of that Secret, and does not start without that key. This part is the same as in v10.5.1.

### 3. Server and migrations tags must share a major version

A Caradhras server refuses a database schema that is behind or ahead of its own release. The render now fails when `caradhras.image.tag` and the migrations tag (`caradhras.migrations.image.tag`, or the legacy `auth.backend.migrations.image.tag`) are semantic versions with different major versions:

```text
ERROR: the Caradhras server tag "2.1.0" and the migrations tag "1.8.6" are on different major versions.
   A server refuses a schema that is behind or ahead of its own release.
   Set caradhras.image.tag and caradhras.migrations.image.tag to the same release (the legacy auth.backend.migrations.image.tag counts as the migrations tag).
```

For example, the render fails for a release that sets the migrations tag to `1.8.6` and keeps the server tag on the new default `2.1.0`. The check skips a tag that is not a semantic version, such as `latest` or a bare digest.

### 4. Pod templates drop the helm.sh/chart label

The pod templates of the `auth`, `identity`, `caradhras` and `caradhras-ui` Deployments no longer carry the `helm.sh/chart` label. The objects that carried it before keep it, for example the Deployments, Services and the auth and identity ConfigMaps. A query, alert or dashboard that selects these pods by `helm.sh/chart` stops matching them. Select them by `app.kubernetes.io/instance` and `app.kubernetes.io/name`.

## Action required

> **Warning:** A release that runs the default Caradhras tag, with no `caradhras.secrets.LICENSE_KEY` and without `caradhras.useExistingSecret: true`, fails `helm upgrade` at the render with the license error above. Nothing in the cluster changes. A release with `caradhras.useExistingSecret: true` renders even when its Secret has no `LICENSE_KEY` key. The upgrade then moves the database to 2.x, and the Caradhras 2.x server refuses to boot. To recover, put a key issued for the product `caradhras` in that Secret. A pin back to `1.8.6` does not recover the release, because a 1.8.x pod refuses the migrated database.

The commands in this guide are examples. Replace `plugin-access-manager` (release name) and `-n midaz-plugins` (namespace) with the values used at install time. Every release does the steps below, also when it already has a Caradhras license key.

1. Save the values of the release. The file holds the license keys and the other secrets of the release. Keep it out of version control and delete it after the upgrade.

   ```bash
   helm get values plugin-access-manager -n midaz-plugins -o yaml > am-values.yaml
   ```

2. Find `caradhras.image.tag` in `am-values.yaml`. If the file does not set it, the release runs the v10.5.1 default `1.8.6`, and this upgrade moves it to `2.1.0`. If the file sets it, the upgrade keeps that tag.

   Before you edit `am-values.yaml`: add the `caradhras:` block when the file has none. When the file already has a `caradhras:`, `image:` or `secrets:` key, add the new key inside it. Do not add a second key with the same name at the same level: Helm keeps only the last one and drops the rest of the earlier block, for example `caradhras.image.repository` or `caradhras.secrets.redisEndpoint`.

   Choose one path:

   - **Move Caradhras to 2.1.0** (the v11.0.0 default):
     1. If `caradhras.image.repository` points at a private registry, copy `ghcr.io/lerianstudio/caradhras:2.1.0` to that repository. If `caradhras.migrations.image.repository` or the legacy `auth.backend.migrations.image.repository` points at a private registry, copy `ghcr.io/lerianstudio/caradhras-migrations:2.1.0` to that repository. The two values are independent: each image comes from its own repository value, or from `ghcr.io/lerianstudio` when that value is empty. Copy the images before the upgrade: the `migrate` init container runs before the server image is pulled.
     2. Get a license key for the product `caradhras` from Lerian.
     3. If the release sets `caradhras.useExistingSecret: true`, do not add the key to the file. Add a `LICENSE_KEY` key to the Secret that `caradhras.existingSecretName` names. Otherwise, add the key under `secrets` inside the `caradhras:` block of `am-values.yaml`:

        ```yaml
        caradhras:
          # other caradhras values stay here
          secrets:
            LICENSE_KEY: "<caradhras license key>"
        ```

     4. If `am-values.yaml` sets `caradhras.image.tag`, remove it, or set it to `"2.1.0"`.
   - **Keep Caradhras 1.8.6** (only when the file does not set `caradhras.image.tag`; move the chart now and Caradhras later): add `tag: "1.8.6"` under `image` inside the `caradhras:` block of `am-values.yaml`. The migrations tag follows it, and the release needs no Caradhras license key.
   - **Keep the tag that the file already sets**: a tag that is a semantic version below `2.0.0` needs no Caradhras license key. Any other tag, such as a 2.x tag, a `2.0.0` prerelease or `latest`, needs one. Do item 3 of the first path when the release has none.

3. Find `caradhras.migrations.image.tag` and `auth.backend.migrations.image.tag` in `am-values.yaml`. Remove `auth.backend.migrations.image.tag`. Remove `caradhras.migrations.image.tag` too, unless it carries an `@sha256:` digest that you want to keep. The migrations tag then follows the server tag, without a digest. To keep a migrations tag or digest, set `caradhras.migrations.image.tag` to the same release as `caradhras.image.tag`, with the digest of the `caradhras-migrations` image.

With the pin to `1.8.6`, the rendered manifests are the same as v10.5.1 except for the `helm.sh/chart` label and what follows from it: the label leaves the pod templates, and the pod-template checksums that hash a chart ConfigMap or Secret with that label change. The `auth` and `identity` ConfigMaps always carry the label, and the `caradhras` pod template also hashes the `auth` ConfigMap, so the `auth`, `identity` and `caradhras` pod templates always change. The `auth`, `identity` and `caradhras` pods, and the `caradhras-ui` pod when it is enabled, restart once with the usual rolling update. The bundled PostgreSQL and Valkey pods do not restart.

## Preview changes before upgrading

Pass the values file from step 1, also when you did not change it. Without `-f`, `helm diff` fills in the values of the installed v10.5.1 chart, including its default Caradhras tag `1.8.6`, and does not show the move to `2.1.0` that the upgrade makes. A `-f` file replaces the stored values, so the file must hold all of them:

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 11.0.0 -n midaz-plugins -f am-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

If this upgrade moves Caradhras from 1.x to 2.x, back up the Caradhras database right before you run the command below. A restore of an older backup loses the Caradhras changes made after it. Caradhras uses the database that `DB_NAME` names in the auth ConfigMap (default `casdoor`), on the auth database server. With the bundled database, that server is the `<release>-auth-database` StatefulSet. Use your usual PostgreSQL backup tool, for example `pg_dump`.

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 11.0.0 -n midaz-plugins -f am-values.yaml
```

## Verify

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/instance=plugin-access-manager
kubectl rollout status deployment/plugin-access-manager-caradhras -n midaz-plugins
kubectl get deployment plugin-access-manager-caradhras -n midaz-plugins -o jsonpath='{range .spec.template.spec.initContainers[*]}{.image}{"\n"}{end}{.spec.template.spec.containers[0].image}{"\n"}'
helm status plugin-access-manager -n midaz-plugins
```

With the release name `plugin-access-manager`, the Deployments are `plugin-access-manager-auth`, `plugin-access-manager-identity` and `plugin-access-manager-caradhras`. For another release name, they start with that name.

All pods reach `Running` and `Ready`, and `helm status` shows `deployed`. Run the same `rollout status` check for `plugin-access-manager-auth` and `plugin-access-manager-identity`.

The image command prints the `wait-for-dependencies` image (`busybox`), then the `migrate` image, then the server image. The `migrate` image and the server image show the same version: `2.1.0` after the move, `1.8.6` with the pin, or the tag that the file sets. When the server tag carries an `@sha256:` digest, the server image shows it, and the `migrate` image shows the version without it, unless `caradhras.migrations.image.tag` sets one.

To read the migrations log, wait until `kubectl get pods` lists no Caradhras pod in `Terminating`. Before that, the command below can print the log of the old pod:

```bash
kubectl logs deployment/plugin-access-manager-caradhras -n midaz-plugins -c migrate
```
<!-- {% endraw %} -->
