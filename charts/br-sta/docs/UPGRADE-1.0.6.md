# Helm Upgrade from v1.0.5 to v1.0.6

This patch release updates the default application version from 1.0.0 to 1.2.0, bringing the latest br-sta application features and fixes to the chart.

## Application Version Update

The `appVersion` field in Chart.yaml has been updated, which changes the default container image tags for the manager, worker, and migrations components.

| Setting | v1.0.5 | v1.0.6 |
|---------|--------|--------|
| `appVersion` | 1.0.0 | 1.2.0 |

### What This Means

The `appVersion` serves as the default image tag for three components:

- Manager deployment
- Worker deployment
- Migrations job

The mock STA Deployment (`mockSta.enabled: true`, off by default) also uses `appVersion` when `mockSta.image.tag` is not set.

Unless you have explicitly overridden image tags in your `values.yaml`, this upgrade will pull and deploy version 1.2.0 of the br-sta application images.

### Action Required

In 1.2.0, `POST /v1/transfers` and `POST /v1/inbound-source-configs/{id}/trigger-poll` require the `X-Idempotency` header, and a request without it is refused with `400`. Before you upgrade, make sure every client that calls these routes sends the header.

In 1.2.0, br-sta stamps every business fact with the tenant `default` and ignores `common.app.defaultTenantId`. If br-sisbajud consumes br-sta facts (`brSisbajud.sta.consumerEnabled: true`), upgrade br-sisbajud to chart 1.4.0 or later: earlier versions refuse a fact whose tenant differs from `brSisbajud.sta.expectedTenantSt`.

The 1.2.0 migrations drop the `audit_outbox` table and keep none of its rows: a row still pending (`published_at` empty) when the migrations run is never delivered. The 1.0.0 manager and worker write that table, so stop them before you check it:

1. Scale the manager Deployment to 0 replicas, then wait for the worker to publish the pending rows.
2. Scale the worker Deployment to 0 replicas.
3. Check that `audit_outbox` has no row with `published_at` empty.
4. Run the upgrade. It sets the replicas back from your values. With `manager.autoscaling.enabled: true` the chart sets no manager replicas, so scale the manager back to `manager.autoscaling.minReplicas` after the upgrade.

**If you have NOT overridden image tags:**

The upgrade will automatically use the new 1.2.0 images.

**If you HAVE overridden image tags:**

Check your `values.yaml` for any of these overrides:

```yaml
manager:
  image:
    tag: "custom-tag"

worker:
  image:
    tag: "custom-tag"

migrations:
  image:
    tag: "custom-tag"
```

If you want to adopt the new 1.2.0 version, remove these overrides or update them to `"1.2.0"`.

> **Important:** The migrations job runs database schema updates. If you maintain custom image tags, ensure your migrations image version is compatible with your manager and worker versions.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.6
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm -n br-sta --version 1.0.6
```
