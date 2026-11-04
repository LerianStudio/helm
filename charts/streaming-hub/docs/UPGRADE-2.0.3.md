# Helm Upgrade from v2.0.2 to v2.0.3

## Topics

- **[Application Version Update](#application-version-update)**
- **[Database migrations](#database-migrations)**
- **[Behavior changes in 3.1.0](#behavior-changes-in-310)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Application Version Update

The chart now ships with a newer application version.

| Setting | v2.0.2 | v2.0.3 |
|---------|--------|--------|
| Chart version | `2.0.2` | `2.0.3` |
| App version | `3.0.0` | `3.1.0` |

**Impact:** This is a patch-level chart update that bumps the default application image tag from `3.0.0` to `3.1.0`. The application version moves from a stable release to a newer stable release.

**Configuration:**

If you pinned the image tag in your values, the pin stays active and the hub (and the migration Job, which follows the same tag) stays on that version. Set it to `3.1.0`, or remove it, to upgrade the app:

```yaml
streamingHub:
  image:
    tag: "3.1.0"
```

If you do not set `streamingHub.image.tag`, the upgrade moves the hub to `3.1.0`, the new default in the chart's `values.yaml`. The image change restarts the hub pods (rolling update).

**Migration required:** No chart-level configuration changes are required for this version bump. App `3.1.0` adds database migrations: see [Database migrations](#database-migrations). For behavioral changes, bug fixes and new features, review the application release notes for `3.1.0`.

> **Note:** The application image repository remains unchanged (`ghcr.io/lerianstudio/streaming-hub`). Only the default tag is updated.

---

## Database migrations

App `3.1.0` adds migrations `000042` to `000044`. The hub reports ready only when the database schema is at version `44` or higher, so the new pods stay NotReady until these migrations are applied.

- With `streamingHub.migrations.enabled=true`, the chart's migration Job (Helm `pre-upgrade` hook, Argo CD `PreSync`) runs `ghcr.io/lerianstudio/streaming-hub-migrations:3.1.0` before the Deployment rolls out.
- With `streamingHub.migrations.enabled=false` (the default), apply migrations `000042` to `000044` yourself before the new pods start.

Pods still on `3.0.0` require schema version `41` exactly and report NotReady once the migrations run. Expect the hub API to be unavailable from the migration until the new pods are Ready.

**Rollback:** after the migrations, `3.0.0` stays NotReady. To go back, run the down migrations from `44` to `41` first. Migration `000043` moves `degraded` subscriptions to `active`, and its down migration does not restore them. Do not use `--atomic` for this upgrade: a Helm rollback restores `3.0.0` and leaves the new schema applied.

---

## Behavior changes in 3.1.0

- **Single-tenant mode:** the hub now attributes every consumed event to `STREAMING_HUB_TENANT_ID` and ignores `ce-tenantid`. It delivers every event on the topics it reads to that tenant's subscriptions, so a single-tenant hub needs a dedicated Kafka bus. Events that earlier versions quarantined (`missing_tenant`) or stored under another tenant are not re-delivered automatically.
- **Pre-stop drain:** `STREAMING_HUB_PRE_STOP_DRAIN_TIMEOUT` above `60s` now refuses the boot. The default is `5s`.

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm --version 2.0.3 -n streaming-hub
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm --version 2.0.3 -n streaming-hub
```
