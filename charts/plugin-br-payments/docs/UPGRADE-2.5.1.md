# Helm Upgrade from v2.5.0 to v2.5.1

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Application version upgrade to 1.4.0](#1-application-version-upgrade-to-140)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.5.0` to `2.5.1`. This is a patch release that upgrades the application version from `1.3.0` to `1.4.0`. The chart updates the default image tag to match the new application version.

No new chart configuration keys are introduced, but application `1.4.0` changes authorization behavior. Complete the scoped-client compatibility checks below before upgrading. Changing the effective application image triggers a rolling restart; preserving an image pin does not guarantee that other pod-template checksums remain unchanged.

## Changes

### 1. Application version upgrade to 1.4.0

The chart now deploys application version `1.4.0` (previously `1.3.0`). The `appVersion` field in `Chart.yaml` and the default `app.image.tag` in `values.yaml` have been updated to reflect this version bump.

**Before (v2.5.0):**

```yaml
# Chart.yaml
appVersion: "1.3.0"

# values.yaml
app:
  image:
    tag: "1.3.0"
```

**After (v2.5.1):**

```yaml
# Chart.yaml
appVersion: "1.4.0"

# values.yaml
app:
  image:
    tag: "1.4.0"
```

#### Operational impact

- **Existing deployments**: If you have not overridden `app.image.tag` in your values overlay, the upgrade will automatically pull and deploy the `1.4.0` image. Kubernetes will perform a rolling restart of the application pods.

- **Custom image tag overrides**: If you explicitly set `app.image.tag` in your values overlay to pin a specific version, the upgrade will not change your deployed image. You must manually update your values overlay to `1.4.0` to receive the application update:

```yaml
app:
  image:
    tag: "1.4.0"
```

#### Application compatibility checks

Application `1.4.0` wires partner organization scope during authentication-provider initialization, independently of the IDP permission-publisher environment variables. An invalid scope declaration fails initialization. This is application behavior, not a new Helm setting.

Before cutover, validate representative partner credentials and grants in a safe test environment. Confirm that the intended organization is authorized, that integrations handle `X-Organization-Id` on the declared boleto, payment and dashboard routes, and that cross-organization requests are refused. Scope extraction is route-specific, not a header accepted globally. Tenant-wide administrative operations and `POST /v1/payments/{id}/cancel` are not declared scoped-partner capabilities; do not assume an existing partner can call them. Keep authentication enabled; resolve grant/client incompatibilities rather than bypassing authorization.

> **Availability:** Multiple replicas and a PodDisruptionBudget alone do not guarantee zero downtime; a PDB does not govern a Deployment's own rolling update. Verify Ready capacity, surge resources, working dependencies, compatible configuration and graceful shutdown, and observe the rollout with a recovery plan.

## Configuration Changes

| Setting | v2.5.0 | v2.5.1 |
|---------|--------|--------|
| `app.image.tag` | `"1.3.0"` | `"1.4.0"` |

No other configuration values were added, removed, or changed.

## Migration Steps

Before editing configuration, save owner-only release values, manifests and revision history in a fresh private directory (`umask 077`). These exports may contain credentials: never commit or share them, and remove them securely when no longer needed. Preserve unrelated configuration, external Secret references and image pins in a complete intended `values.yaml`. Obtain consistent datastore backups and a tested recovery plan before cutover. The preview and upgrade below explicitly reset stored overrides and load that complete file; a partial overlay is not sufficient with `--reset-values`.

Complete the application compatibility checks above. Replace the example namespace and release name `my-payments` in all commands/selectors with your actual deployment.

1. **(Optional)** If you override `app.image.tag` in your values overlay, update it to `1.4.0`:

```yaml
app:
  image:
    tag: "1.4.0"
```

2. **Run the upgrade** during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. **Monitor the rolling restart** of application pods:

```bash
kubectl rollout status deployment -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments,app.kubernetes.io/instance=my-payments
```

4. **Verify all pods are running the new image version**:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments,app.kubernetes.io/instance=my-payments -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

Expected output should show image tag `1.4.0` for all pods.

5. **Verify application health** after the upgrade:

```bash
kubectl get pods -n midaz-plugins -l app.kubernetes.io/name=plugin-br-payments,app.kubernetes.io/instance=my-payments
```

Every expected replica must be Ready; the `READY` column counts ready containers per pod (normally `1/1` without sidecars), not the replica count. Also verify application readiness and representative authorized API operations; `Running` alone does not establish health.

> **Warning:** If pods fail to start after the upgrade, check the pod logs for application errors related to the `1.4.0` version. You may need to roll back to `2.5.0` while investigating compatibility issues.

Helm rollback changes Kubernetes resources and images; it does not restore database contents or undo writes made by the new application. Select the actual previous release revision from your private history, evaluate application/data compatibility and use the tested restore plan if data recovery is necessary.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.5.1 --reset-values -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.5.1 --reset-values -f values.yaml
```
