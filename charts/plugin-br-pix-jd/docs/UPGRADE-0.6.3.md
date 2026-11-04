<!-- {% raw %} -->
# Helm Upgrade from v0.6.2 to v0.6.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Pod Label Stability](#1-pod-label-stability)
  - [2. Documentation Updates](#2-documentation-updates)
- **[Migration Impact](#migration-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that improves pod label stability and updates documentation. The upgrade prevents unnecessary pod restarts during chart upgrades by removing the chart version label from pod templates.

| Setting | v0.6.2 | v0.6.3 |
|---------|--------|--------|
| Chart Version | 0.6.2 | 0.6.3 |
| App Version | 1.6.1 | 1.6.1 |
| Breaking Changes | None | None |

## Fixes

### 1. Pod Label Stability

**What changed:**

The chart now uses a new `componentPodLabels` helper that excludes the `helm.sh/chart` label from pod templates. Previously, every chart upgrade would change the `helm.sh/chart` label value (e.g., from `plugin-br-pix-jd-0.6.2` to `plugin-br-pix-jd-0.6.3`), forcing Kubernetes to recreate all pods even when no application configuration changed.

**Before (v0.6.2):**

```yaml
# Pod template labels included helm.sh/chart
labels:
  helm.sh/chart: plugin-br-pix-jd-0.6.2
  app.kubernetes.io/name: plugin-br-pix-jd
  app.kubernetes.io/instance: plugin-br-pix-jd
  app.kubernetes.io/component: api
  app.kubernetes.io/version: "1.6.1"
  app.kubernetes.io/managed-by: Helm
```

**After (v0.6.3):**

```yaml
# Pod template labels exclude helm.sh/chart
labels:
  app.kubernetes.io/name: plugin-br-pix-jd
  app.kubernetes.io/instance: plugin-br-pix-jd
  app.kubernetes.io/component: api
  app.kubernetes.io/version: "1.6.1"
  app.kubernetes.io/managed-by: Helm
```

**Why this matters:**

- **Reduces downtime:** Chart upgrades that only bump the version number (like this one) no longer trigger pod restarts
- **Preserves availability:** Pods continue running with existing connections intact when no functional changes are deployed
- **Improves upgrade speed:** Helm sync completes faster without waiting for pod rollouts

**Operational impact:**

The `helm.sh/chart` label is still present on **Deployment, Service, ConfigMap, and other top-level resources** — only pod templates are affected. This means:

- You can still query resources by chart version using label selectors on Deployments
- Pod selectors remain stable across upgrades
- Existing pods from v0.6.2 will **not** be restarted during the upgrade to v0.6.3 unless you also change values

**Components affected:**

- API Deployment (`templates/api/deployment.yaml`)
- Worker Deployment (`templates/worker/deployment.yaml`)
- Migrations Job (`templates/common/migrations-job.yaml`)

> **Note:** This change is transparent to operators. No configuration changes are required, and the upgrade will not restart pods unless you modify `values.yaml` settings that affect pod specs (image tags, environment variables, resources, etc.).

### 2. Documentation Updates

**What changed:**

The chart metadata and inline documentation have been updated for clarity and accuracy:

#### Chart.yaml

- **Removed obsolete source link:** The `sources` list previously included `https://github.com/LerianStudio/plugin-br-pix-jd`, which has been removed. The chart repository link remains.

**Before (v0.6.2):**

```yaml
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/plugin-br-pix-jd
  - https://github.com/LerianStudio/plugin-br-pix-jd
```

**After (v0.6.3):**

```yaml
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/plugin-br-pix-jd
```

- **Improved Valkey dependency comment:** The Portuguese comment explaining the bundled Valkey subchart has been reworded for clarity. The functionality is unchanged — Valkey remains disabled by default.

**Before (v0.6.2):**

```yaml
# Valkey EMBARCADO, desligado por default — mesma postura do postgresql acima e do
# go-boilerplate-ddd-helm, que é o chart de referência desta wiring. Só a lane
# `chaos` do anacleto liga: injeção de falha precisa de datastore descartável.
```

**After (v0.6.3):**

```yaml
# Valkey EMBARCADO, desligado por default — mesma postura do postgresql acima e do
# go-boilerplate-ddd-helm, que é o chart de referência desta wiring. Ligue-o quando
# o ambiente precisar de um datastore descartável (ex.: injeção de falha).
```

Translation: "Enable it when the environment needs a disposable datastore (e.g., fault injection)."

#### Template helpers

- **Updated TLS comment:** The `ALLOW_INSECURE_TLS` environment variable comment in `_helpers.tpl` has been generalized from referencing specific test environments ("benedita") to a broader explanation.

**Before (v0.6.2):**

```go
{{- /* ALLOW_INSECURE_TLS — modeled as a first-class key, not left to the escape hatch,
   because the benedita test environments run Postgres, Valkey and RabbitMQ WITHOUT TLS
```

**After (v0.6.3):**

```go
{{- /* ALLOW_INSECURE_TLS — modeled as a first-class key, not left to the escape hatch,
   because test environments may run Postgres, Valkey and RabbitMQ WITHOUT TLS
```

- **Updated streaming broker example:** The error message for missing `STREAMING_BROKERS` now uses a generic example domain instead of a specific internal hostname.

**Before (v0.6.2):**

```go
{{- fail "\n\nERROR: STREAMING_BROKERS is required when STREAMING_ENABLED=true.\nComma-separated Kafka broker list, e.g. redpanda.dev-st.lerian.net:9092\n" -}}
```

**After (v0.6.3):**

```go
{{- fail "\n\nERROR: STREAMING_BROKERS is required when STREAMING_ENABLED=true.\nComma-separated Kafka broker list, e.g. redpanda.example.com:9092\n" -}}
```

**Why this matters:**

These documentation changes improve chart maintainability and remove environment-specific references that could confuse operators. No functional behavior is affected.

## Migration Impact

**No action required.** This upgrade can be applied directly to existing v0.6.2 installations without configuration changes.

> **Important:** The upgrade will **not** restart your pods unless you are also changing values that affect pod specs (e.g., `api.image.tag`, `api.resources`, `api.configmap`, etc.). The pod label stability fix ensures that version-only upgrades are non-disruptive.

**What happens during the upgrade:**

1. Helm updates the chart metadata on Deployments, Services, and ConfigMaps
2. Pod templates are updated with the new label structure (removing `helm.sh/chart`)
3. Kubernetes compares the new pod template to the existing one
4. Since no functional fields changed, the Deployment's `observedGeneration` increments but no rollout occurs
5. Existing pods continue running

**Verification:**

After upgrading, confirm that pods were not restarted:

```bash
kubectl -n midaz-plugins get pods -l app.kubernetes.io/name=plugin-br-pix-jd -o wide
```

Check the `AGE` column — pods should retain their original creation timestamp if you did not modify any values.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.6.3
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.6.3
```
<!-- {% endraw %} -->
