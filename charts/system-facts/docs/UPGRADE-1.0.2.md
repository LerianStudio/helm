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

This release changes only `Chart.yaml` (`version`, `appVersion`) and three image tag defaults in `values.yaml`. There are no changes to:

- Values schema or configuration options
- Template files (Deployments, Services, ConfigMaps, etc.)
- Dependencies or subcharts

The rendered ConfigMap keys `VERSION` and `OTEL_RESOURCE_SERVICE_VERSION` follow the service image tag, so they change from `1.0.0` to `1.1.0`.

The upgrade rolls the System Facts pods, and the worker pods if `worker.enabled` is `true`. Their pod templates carry a `helm.sh/chart` label, so any chart version bump rolls them, even if you pin the image tags. The migrations Job (`migrations.enabled`, default `false`) is covered under [Migrations Runner](#migrations-runner).

---

## Breaking Changes

**None in the chart.** The templates and values schema are unchanged, so existing values remain valid. What the application `1.1.0` itself changes is not described by this chart diff.

If you upgrade with `--reuse-values`, the image tag will not move. See [Migration Steps](#migration-steps).

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

When you upgrade to v1.0.2, Kubernetes performs a rolling update of the System Facts Deployment to run the `1.1.0` image. The chart defaults are `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 1`, one replica (`system-facts.replicaCount: 1`, `autoscaling.minReplicas: 1`) and a PodDisruptionBudget with `maxUnavailable: 1`. With a single replica, the old pod can be removed before the new one is Ready, so expect a short interruption. Run two or more replicas to keep the service available during the rollout.

> **Note:** If you have overridden `system-facts.image.tag` in your values file, remove the override to use the chart default, or update it to `"1.1.0"` explicitly. A pinned tag keeps the old image, but the pods still roll because of the `helm.sh/chart` label.

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

`migrations.enabled` defaults to `false`; if you have not enabled it, nothing changes here. If it is `true`, the Job runs with the `1.1.0` runner image. The Job is an ArgoCD Sync hook (`argocd.argoproj.io/hook: Sync`, delete policy `BeforeHookCreation,HookSucceeded`). It is deliberately not PreSync, because it reads `POSTGRES_PASSWORD` from a Secret this chart renders, and the chart has no `helm.sh/hook` annotation, so Helm does not order it before the Deployment. A failed Sync hook fails the ArgoCD sync.

> **Important:** The migrations Job applies the root schema sequence (`/migrations`, table `schema_migrations`) only. The tenant-partition sequence stays with the service. Review the application release notes for schema changes between `1.0.0` and `1.1.0`.

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

`worker.enabled` defaults to `false`; if you have not enabled it, nothing changes here. If it is `true`, Kubernetes performs a rolling update of the worker Deployment to the `1.1.0` image. The chart defaults are `maxSurge: 1` and `maxUnavailable: 0`, so a new pod starts before the old one is removed.

> **Note:** The worker consumes events from RedPanda. Each replaced pod closes its consumer on shutdown; the chart enforces `worker.terminationGracePeriodSeconds` of at least `60` (consumer close 30 s, admin drain 10 s, telemetry flush) so that close can finish.

---

## Migration Steps

No values changes are required. Apply the upgrade without `--reuse-values`, as shown in Step 3.

### Step 1: Verify current deployment

Confirm your current chart version:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.0.1` and `APP VERSION` should show `1.0.0`.

### Step 2: Review application release notes

Before upgrading, review the System Facts application release notes for version `1.1.0`, in particular any database schema migrations and configuration changes.

> **Important:** This Helm chart upgrade only updates the image tags. Any application-level changes are documented in the application release notes, not in this Helm upgrade guide.

### Step 3: Apply the upgrade

Upgrade to version `1.0.2`, keeping your existing values:

```bash
helm upgrade system-facts oci://registry-1.docker.io/lerianstudio/system-facts-helm \
  --version 1.0.2 \
  --namespace system-facts \
  --reset-then-reuse-values
```

> **Warning:** Do not use `--reuse-values` for this upgrade. Helm then replaces the new chart's built-in defaults with the previous release's, so `system-facts.image.tag` stays at `"1.0.0"` while the empty `migrations.image.tag` and `worker.image.tag` follow the new `appVersion` (`1.1.0`). The service would run `1.0.0` next to a `1.1.0` worker and runner. `--reset-then-reuse-values` (Helm 3.14 or later) takes the new defaults and applies the values you set on the previous release on top.

> **Note:** An anonymous pull from `registry-1.docker.io` is refused with `401`. Without Docker Hub access, use `oci://ghcr.io/lerianstudio/system-facts-helm`.

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

> **Note:** The Job is removed when it succeeds (`HookSucceeded`, and `ttlSecondsAfterFinished` defaults to `600`), so a missing Job after a successful sync is expected.

### Step 5: Verify the upgrade

Confirm the chart version was updated:

```bash
helm list -n system-facts
```

The `CHART` column should show `system-facts-helm-1.0.2` and `APP VERSION` should show `1.1.0`.

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
