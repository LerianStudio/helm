# Helm Upgrade from v1.0.1 to v1.0.2

This guide covers the upgrade of the `system-facts` Helm chart from version **1.0.1** to **1.0.2**. This is a patch release that updates the application version from **1.0.0** to **1.1.0** across all components.

---

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
- **[Application Version Update](#application-version-update)**
  - [System Facts Service](#system-facts-service)
  - [Migrations Runner](#migrations-runner)
  - [Internal Facts Worker](#internal-facts-worker)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

Version **1.0.2** updates the application version (`appVersion`) from **1.0.0** to **1.1.0** and sets explicit image tags for all components:

- **System Facts service**: Image tag updated from `1.0.0` to `1.1.0`
- **Migrations runner**: Image tag updated from empty (tracking appVersion) to explicit `1.1.0`
- **Internal facts worker**: Image tag updated from empty (tracking appVersion) to explicit `1.1.0`

This release changes only the application version and image tags. There are no changes to:

- Values schema or configuration options
- Template files (Deployments, Services, ConfigMaps, etc.)
- Environment variables or application configuration
- Dependencies or subcharts

The upgrade will trigger a rolling restart of all pods to pull and run the new application version.

---

## Breaking Changes

**None.** This is a patch release with no breaking changes. All existing configurations remain compatible.

---

## Application Version Update

### System Facts Service

The System Facts service image tag has been updated to version **1.1.0**.

**Image tag change:**

| Setting | v1.0.1 | v1.0.2 |
|---------|--------|--------|
| `system-facts.image.tag` | `"1.0.0"` | `"1.1.0"` |

**Before (v1.0.1):**

```yaml
system-facts:
  image:
    repository: ghcr.io/lerianstudio/system-facts
    tag: "1.0.0"
    pullPolicy: IfNotPresent
```

**After (v1.0.2):**

```yaml
system-facts:
  image:
    repository: ghcr.io/lerianstudio/system-facts
    tag: "1.1.0"
    pullPolicy: IfNotPresent
```

**Operational impact:**

When you upgrade to v1.0.2, Kubernetes will perform a rolling restart of the System Facts Deployment to pull and run the `1.1.0` image. Pods will be replaced one at a time (or according to your `rollingUpdate` strategy), ensuring zero downtime if you have multiple replicas and a properly configured `PodDisruptionBudget`.

> **Note:** If you have overridden `system-facts.image.tag` in your values file, remove the override to use the chart default, or update it to `"1.1.0"` explicitly.

### Migrations Runner

The migrations runner image tag has been updated from empty (which tracked the chart `appVersion`) to an explicit `"1.1.0"`.

**Image tag change:**

| Setting | v1.0.1 | v1.0.2 |
|---------|--------|--------|
| `migrations.image.tag` | `""` (tracked appVersion `1.0.0`) | `"1.1.0"` |

**Before (v1.0.1):**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/system-facts-migrations
    tag: ""
    pullPolicy: IfNotPresent
```

**After (v1.0.2):**

```yaml
migrations:
  image:
    repository: ghcr.io/lerianstudio/system-facts-migrations
    tag: "1.1.0"
    pullPolicy: IfNotPresent
```

**Operational impact:**

If `migrations.enabled` is `true`, the migrations Job will run with the `1.1.0` runner image during the next Helm upgrade. The Job is an ArgoCD Sync-hook that runs before the service Deployment is updated. If the Job fails, the upgrade will be blocked.

> **Important:** The migrations Job applies the root schema sequence (`/migrations`). Ensure the `1.1.0` migrations runner is compatible with your database schema. Review the application release notes for any schema changes between `1.0.0` and `1.1.0`.

### Internal Facts Worker

The internal facts worker image tag has been updated from empty (which tracked the chart `appVersion`) to an explicit `"1.1.0"`.

**Image tag change:**

| Setting | v1.0.1 | v1.0.2 |
|---------|--------|--------|
| `worker.image.tag` | `""` (tracked appVersion `1.0.0`) | `"1.1.0"` |

**Before (v1.0.1):**

```yaml
worker:
  image:
    repository: ghcr.io/lerianstudio/system-facts-worker
    tag: ""
    pullPolicy: IfNotPresent
```

**After (v1.0.2):**

```yaml
worker:
  image:
    repository: ghcr.io/lerianstudio/system-facts-worker
    tag: "1.1.0"
    pullPolicy: IfNotPresent
```

**Operational impact:**

If `worker.enabled` is `true`, Kubernetes will perform a rolling restart of the worker Deployment to pull and run the `1.1.0` image. Pods will be replaced one at a time (or according to your `rollingUpdate` strategy).

> **Note:** The worker consumes events from RedPanda/Kafka. During the rolling restart, some partitions may experience brief processing delays as consumer group rebalancing occurs. This is normal behavior and does not result in data loss.

---

## Migration Steps

No configuration changes are required. The upgrade can be applied directly with your existing values.

### Step 1: Verify current deployment

Confirm your current chart version:

```bash
helm list -n system-facts
```

Expected output should show version `1.0.1`.

### Step 2: Review application release notes

Before upgrading, review the System Facts application release notes for version `1.1.0` to understand what changed in the application itself. Check for:

- New features or bug fixes
- Database schema migrations
- Configuration changes or deprecations
- Breaking changes in the application API

> **Important:** This Helm chart upgrade only updates the image tags. Any application-level changes (new environment variables, configuration options, or behavioral changes) are documented in the application release notes, not in this Helm upgrade guide.

### Step 3: Apply the upgrade

Upgrade to version `1.0.2` using your existing values:

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm \
  --version 1.0.2 \
  --namespace system-facts \
  --reuse-values
```

> **Note:** The `--reuse-values` flag preserves your existing configuration. No values changes are required for this upgrade.

### Step 4: Monitor the upgrade

Watch the rollout status for the System Facts service:

```bash
kubectl rollout status deployment/system-facts -n system-facts
```

If the worker is enabled, monitor its rollout:

```bash
kubectl rollout status deployment/system-facts-worker -n system-facts
```

If migrations are enabled, check the Job status:

```bash
kubectl get jobs -n system-facts
kubectl logs -n system-facts job/system-facts-migrations
```

### Step 5: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

Expected output should show version `1.0.2`.

Verify that all pods are running the new image version:

```bash
kubectl get pods -n system-facts -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'
```

Expected output should show `ghcr.io/lerianstudio/system-facts:1.1.0` for the service and `ghcr.io/lerianstudio/system-facts-worker:1.1.0` for the worker (if enabled).

### Step 6: Test the service

Verify the service is responding correctly:

```bash
kubectl port-forward -n system-facts svc/system-facts 8080:8080
curl http://localhost:8080/health
```

If Swagger is enabled, access the documentation to confirm the API is available:

```bash
curl http://localhost:8080/swagger/index.html
```

---

## Preview changes before upgrading

```bash
helm diff upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.0.2 -n system-facts
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm --version 1.0.2 -n system-facts
```
