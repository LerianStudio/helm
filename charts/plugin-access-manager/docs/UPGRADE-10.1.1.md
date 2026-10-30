<!-- {% raw %} -->
# Helm Upgrade from v10.1.0 to v10.1.1

# Topics

- **[Overview](#overview)**
- **[Before you upgrade](#before-you-upgrade)**
  - [Back up the database](#back-up-the-database)
  - [This upgrade goes one way](#this-upgrade-goes-one-way)
  - [Check for pinned image tags](#check-for-pinned-image-tags)
- **[Caradhras Image Update](#caradhras-image-update)**
  - [Database migrations](#database-migrations)
  - [Behavior changes between 1.5.1 and 1.8.5](#behavior-changes-between-151-and-185)
  - [Rollout behavior](#rollout-behavior)
- **[After the upgrade: mask old audit records](#after-the-upgrade-mask-old-audit-records)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

This release updates the Caradhras (auth backend) container images from `1.5.1` to `1.8.5`.

> **Important:** This is not a patch update. The chart version moves by a patch number, but Caradhras moves by three minor versions (1.6, 1.7 and 1.8). The `migrate` init container applies 3 schema migrations (`000019` to `000021`) and 10 RBAC migrations (`85` to `94`) to your database. You cannot undo them with a rollback. Read [Before you upgrade](#before-you-upgrade) first.

| Component | v10.1.0 | v10.1.1 |
|-----------|---------|---------|
| Chart version | 10.1.0 | 10.1.1 |
| App version | 3.13.1 | 3.13.1 |
| `caradhras.image.tag` (default) | `1.5.1` | `1.8.5` |
| `caradhras.migrations.image.tag` (default) | `1.5.1` | `1.8.5` |

# Before you upgrade

### Back up the database

Take a backup or a snapshot of the Caradhras database before you upgrade. The backup is the only way back, as the next section explains.

### This upgrade goes one way

The migration applier only moves forward. It has no down migration. Caradhras `1.5.1` refuses a database that a newer image already migrated. After this upgrade you cannot return to `1.5.1` with `helm rollback`, or with an image pin:

- The `migrate` init container of the old image stops with `migration chain is ahead of this binary` and exit code 1.
- The new pod stays in `Init:Error` or `Init:CrashLoopBackOff`, and the rollout does not finish.
- The old image does not embed the newer migrations, so it has nothing to run and nothing to revert.

To go back to `1.5.1`, restore the database from the backup you took before the upgrade. Forcing the migration chain back with `cmd/migration` rewrites only the version bookkeeping. It does not undo migrations `000019` to `000021` or the RBAC data changes. Contact Lerian support before you try it.

### Check for pinned image tags

A tag that you set in your own values overrides the new default, and the upgrade does not change it. The chart resolves each tag in this order:

1. `caradhras.image.tag` and `caradhras.migrations.image.tag`
2. The legacy `auth.backend.image.tag` and `auth.backend.migrations.image.tag`
3. The chart default (`1.8.5`)

Check both the new and the legacy keys:

```bash
helm get values plugin-access-manager -n plugin-access-manager -o yaml
```

```yaml
caradhras:
  image:
    tag: "..."
  migrations:
    image:
      tag: "..."
auth:
  backend:
    image:
      tag: "..."
    migrations:
      image:
        tag: "..."
```

An old `auth.backend.*` override is easy to miss. If it is set and the `caradhras.*` tag is empty, the legacy tag wins, and the upgrade leaves Caradhras on the old version.

The main image tag and the migrations image tag must be the same version. If you override one, override the other to the same value.

# Caradhras Image Update

**What changed:**

The default image tags for the main Caradhras service and for the migrations init container changed across the chart:

| Setting | v10.1.0 | v10.1.1 |
|---------|---------|---------|
| `caradhras.image.tag` | `1.5.1` | `1.8.5` |
| `caradhras.migrations.image.tag` (default) | `1.5.1` | `1.8.5` |

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

### Database migrations

The `migrate` init container runs first and applies these migrations to your database:

| Chain | Version at `1.5.1` | Version at `1.8.5` | What it does |
|-------|--------------------|--------------------|--------------|
| Schema | `000018` | `000021` | `000019` adds `scope_catalog.integrations`. `000020` adds the SSO directory tables `directory_connection` and `directory_disable`. `000021` adds the index `idx_token_organization_user` on `token`. |
| RBAC | `84` | `94` | Ten data migrations (`85` to `94`) that add or change permissions, roles and grants for Lerian products. |

`000021` runs `CREATE INDEX CONCURRENTLY`. Reads and writes on `token` continue while the index builds, but the build takes longer on a larger table. The applier stops a run that exceeds its work budget, which is `300` seconds by default. For a very large `token` table, raise the budget before you upgrade, with the `caradhras.migrations.extraEnvVars` option (available since chart v10.1.0):

```yaml
caradhras:
  migrations:
    extraEnvVars:
      MIGRATIONS_TIMEOUT_SEC: "900"
```

If the index build fails, PostgreSQL leaves an invalid index behind and the schema chain is marked dirty at version 21. Do not run the applier again before you repair it. Follow the "Dirty at 21" section of the Caradhras `migrations/README.md`, or contact Lerian support.

### Behavior changes between 1.5.1 and 1.8.5

These changes come from the Caradhras release notes. The list covers what operators and users can notice.

- **Turned-off users (1.7.0).** Caradhras refuses a disabled user before the MFA prompt, refuses the access keys of turned-off users, and revokes access when an administrator forbids a user. It also refuses to rebind an SSO account that is already linked, and it reports the token of a deleted application as inactive.
- **SSO directory (1.7.0).** New tables and routes store a Google directory connection per organization and record the accounts that a directory sync turns off.
- **Google One Tap removed (1.8.1).** Caradhras removes the Google One Tap login path.
- **Passkeys for server-to-server callers (1.8.0).** Caradhras adds a passkey ceremony for server-to-server callers.
- **Shared applications (1.8.4 and 1.8.5).** Caradhras unmasks a shared application only for administrators of both of its organizations.
- **Audit records (1.8.2 and 1.8.3).** Caradhras masks secrets in new audit records. See [After the upgrade](#after-the-upgrade-mask-old-audit-records).

### Rollout behavior

The Caradhras Deployment uses a rolling update with `maxSurge: 1` and `maxUnavailable: 0`. These values are fixed in the template, and `auth.deploymentStrategy` does not apply to this Deployment. The sequence is:

1. Kubernetes creates one new pod.
2. The new pod runs the `migrate` init container with the `1.8.5` image, and then starts Caradhras `1.8.5`.
3. Kubernetes stops an old pod only after the new pod passes its readiness check.

Auth and identity roll too. The pod templates of the auth, identity and caradhras Deployments carry the label `helm.sh/chart: plugin-access-manager-<version>`, so any chart version bump replaces the pods of all three, even when nothing else in the pod changes. I checked this by rendering the previous and the new chart version with `helm template`. Auth and identity render `maxSurge: 1` and `maxUnavailable: 1` by default (auth runs 3 replicas, identity 1), so identity can be briefly unavailable during the rollout when it runs a single replica.

For Caradhras, a new pod must migrate before an old pod leaves. With `replicaCount: 1` this still holds, and a healthy upgrade does not interrupt the service. If the `migrate` init container fails, the old pod stays in service.

While the rollout runs, the old `1.5.1` pods keep serving on the migrated database. An old pod that restarts in this window fails its boot check, because the database is ahead of its image. Let the rollout finish, and watch it:

```bash
kubectl -n plugin-access-manager rollout status deploy/plugin-access-manager-caradhras
kubectl -n plugin-access-manager logs deploy/plugin-access-manager-caradhras -c migrate
```

The deployment name is `<release>-caradhras`. Use `kubectl -n plugin-access-manager get deploy` to confirm it.

# After the upgrade: mask old audit records

Before Caradhras `1.8.2`, the audit path masked JSON bodies only. Every form or multipart request that it recorded kept its secrets in clear text in `record.object`. This covers the Access Manager login (`client_secret`, `password`), set-password (`oldPassword`, `newPassword`) and the other token endpoints. A copy of each record also lives in `webhook_event.payload`.

Caradhras `1.8.2` and later mask new records. They do not change the rows that are already in the database. After this upgrade, those old rows still hold the clear text.

The Caradhras image includes `/redact-audit-records` (from `1.8.3`). It masks the old rows with the same redactor, and it keeps every row. It replaces secret values with `***` and drops secret query parameters from `request_uri`. A body that the redactor cannot read (raw text, XML, malformed JSON) becomes `***`. A form or multipart body over 64 KiB is cut at 64 KiB.

Lerian runs this tool on Lerian Cloud. In a BYOC deployment, you decide whether to run it. Run it after the environment is on `1.8.2` or later, so that no new row leaks while it runs. A second run finds nothing to change.

1. Dry run. This counts the rows that it would change and writes nothing:

   ```bash
   kubectl -n plugin-access-manager exec deploy/plugin-access-manager-caradhras -- sh -c \
     'POSTGRES_HOST=$DB_HOST POSTGRES_PORT=$DB_PORT POSTGRES_DB=$DB_NAME POSTGRES_USER=$DB_USER \
      POSTGRES_PASSWORD=$DB_PASSWORD POSTGRES_SSLMODE=$DB_SSLMODE /redact-audit-records'
   ```

2. Apply. Run the same command with `/redact-audit-records -apply`.

The tool logs the target (host, port, database) and, per table, the counts `scanned=<n> changed=<n> applied=<bool>`. It never logs a value. It works through `record` and `webhook_event` in batches of 500, with one transaction per batch. On an error it stops, logs the counts so far, and exits with code 1.

> **Note:** The tool does not reach copies outside the database. Backups, dumps and the webhook events that receivers already got keep their values. This includes the backup you take before this upgrade.

# Migration Steps

Follow these steps to upgrade from v10.1.0 to v10.1.1:

**Step 1: Back up the database**

Take a backup or snapshot of the Caradhras database. See [Back up the database](#back-up-the-database).

**Step 2: Review your current image configuration**

Check the new and the legacy image tag keys, as described in [Check for pinned image tags](#check-for-pinned-image-tags).

**Step 3: Decide on your image version**

#### Option 1: Adopt the new default (recommended)

If you do not override the image tags, no change is required. The upgrade deploys Caradhras `1.8.5`.

#### Option 2: Stay on 1.5.1 for now

If you must stay on `1.5.1`, pin both images to the same version in your `values.yaml`, **before** you upgrade:

```yaml
caradhras:
  image:
    tag: "1.5.1"
  migrations:
    image:
      tag: "1.5.1"
```

> **Warning:** This option works only while your database is still at the `1.5.1` schema. After any `1.6` or later image has run the `migrate` init container, `1.5.1` refuses to start. A pin on `1.5.1` is then no way back.

**Step 4: Validate your configuration**

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 10.1.1 \
  -n plugin-access-manager \
  --dry-run \
  --debug
```

Confirm that the Deployment renders the expected image tags for the `caradhras` container and the `migrate` init container.

**Step 5: Upgrade and watch the rollout**

Run the command in [Command to upgrade](#command-to-upgrade). Watch the rollout and the `migrate` log, as described in [Rollout behavior](#rollout-behavior).

**Step 6: Mask old audit records**

Follow [After the upgrade](#after-the-upgrade-mask-old-audit-records).

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
