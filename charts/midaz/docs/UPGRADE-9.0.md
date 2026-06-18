# Helm Upgrade to v9.0.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. `otel-collector-lerian` decoupled from the umbrella chart](#1-otel-collector-lerian-decoupled-from-the-umbrella-chart)
  - [2. `otel-collector-lerian.external` removed](#2-otel-collector-lerianexternal-removed)
  - [3. Default of `otel-collector-lerian.enabled` flipped to `true`](#3-default-of-otel-collector-lerianenabled-flipped-to-true)
  - [4. Subchart config keys removed](#4-subchart-config-keys-removed)
  - [5. Schema tightened on `otel-collector-lerian`](#5-schema-tightened-on-otel-collector-lerian)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version `9.0.0` removes the `otel-collector-lerian` chart from the midaz umbrella as a Helm subchart dependency. The collector is no longer installed by `helm install midaz` — operators must install it as a standalone Helm release (`helm install otel-collector-lerian oci://registry-1.docker.io/lerianstudio/otel-collector-lerian-helm`) or use an existing collector in the cluster.

The `otel-collector-lerian` values block on midaz now controls **only** whether OTEL env vars are injected into the `ledger` and `crm` deployments. It does **not** install or manage the collector.

This is a breaking change for any deployment that:

- Relied on `otel-collector-lerian.enabled: true` to install the collector subchart.
- Used `otel-collector-lerian.external: true` to skip subchart install while still injecting env vars.
- Overrode subchart config (e.g. `otel-collector-lerian.exporters.otlphttp/server.endpoint`, `otel-collector-lerian.extraEnvs`, `otel-collector-lerian.opentelemetry-collector.config.*`).

All of the above scenarios require the migration steps below.

## Breaking Changes

### 1. `otel-collector-lerian` decoupled from the umbrella chart

The dependency was removed from `Chart.yaml`. After upgrading to `9.0.0`, Helm will **delete** any collector that was installed as the midaz subchart (the `otel-collector-lerian` release inside the midaz release name). Plan for one of:

- Install `otel-collector-lerian` as a standalone Helm release **before** upgrading midaz (collector keeps receiving telemetry continuously).
- Accept a brief telemetry gap during the cutover.

To install standalone:

```bash
helm upgrade --install otel-collector-lerian \
  oci://registry-1.docker.io/lerianstudio/otel-collector-lerian-helm \
  --version <pinned-version> \
  --namespace <your-monitoring-namespace> \
  --values <your-collector-values.yaml>
```

The collector values that used to live under `otel-collector-lerian:` in the midaz `values.yaml` should be moved verbatim to the standalone release's values file (with the umbrella key removed).

### 2. `otel-collector-lerian.external` removed

The `external` key no longer exists. The pre-9.0.0 condition `if .enabled OR .external` is now just `if .enabled`.

If your previous values had:

```yaml
otel-collector-lerian:
  enabled: false
  external: true
```

Replace with:

```yaml
otel-collector-lerian:
  enabled: true
```

This preserves the previous behavior: env vars (`HOST_IP`, `POD_IP`, `OTEL_EXPORTER_OTLP_ENDPOINT=$(HOST_IP):4317`, `OTEL_RESOURCE_ATTRIBUTES=k8s.pod.ip=$(POD_IP)`) continue to be injected into the `ledger` and `crm` deployments. Apps still reach a collector on `$(HOST_IP):4317`.

Without this rename, midaz pods will silently lose all OTEL env vars on the next reconcile.

### 3. Default of `otel-collector-lerian.enabled` flipped to `true`

Previously the chart default was `enabled: false, external: false` (no telemetry). The new default is `enabled: true` — every fresh install will attempt to export telemetry to `$(HOST_IP):4317`, which requires an OTEL collector listening on the node.

If you do **not** want telemetry exported from a midaz deployment, explicitly set:

```yaml
otel-collector-lerian:
  enabled: false
```

### 4. Subchart config keys removed

The following keys were valid under `otel-collector-lerian:` in pre-9.0.0 and are now rejected (see Schema below):

- `external` — see Breaking Change 2.
- `extraEnvs` — was used to inject `OTEL_API_KEY` into the subchart. Now belongs in the standalone `otel-collector-lerian` release's values.
- `exporters.*` (e.g. `exporters.otlphttp/server.endpoint`) — same: move to the standalone release.
- `opentelemetry-collector.*` (the full upstream subchart override block) — same.

If your previous values configured a custom OTEL endpoint for the embedded subchart:

```yaml
otel-collector-lerian:
  enabled: true
  exporters:
    otlphttp/server:
      endpoint: "https://my-collector.example.com:443"
```

The new equivalent depends on what your midaz apps should target:

- **Apps reach a node-local collector at `$(HOST_IP):4317`** (the standard pattern — Lerian-provided `otel-collector-lerian` chart as a DaemonSet with hostNetwork or a local DaemonSet that maps hostPort 4317): set `otel-collector-lerian.enabled: true` and configure the standalone release to forward to the desired endpoint.
- **Apps must reach a different endpoint directly** (e.g. a cluster-local collector Service, an external SaaS OTLP gateway): set `otel-collector-lerian.enabled: false` and override the endpoint in the application configmap directly:

  ```yaml
  ledger:
    configmap:
      OTEL_EXPORTER_OTLP_ENDPOINT: "otel-collector.observability.svc.cluster.local:4317"
  crm:
    configmap:
      OTEL_EXPORTER_OTLP_ENDPOINT: "otel-collector.observability.svc.cluster.local:4317"
  ```

### 5. Schema tightened on `otel-collector-lerian`

`values.schema.json` now sets `additionalProperties: false` on the `otel-collector-lerian` object. Only `enabled` is accepted. Any other key (`external`, `extraEnvs`, `exporters`, `opentelemetry-collector`, …) will cause `helm install/upgrade/template` to fail with:

```
Error: values don't meet the specifications of the schema(s) in the following chart(s):
midaz:
- otel-collector-lerian: Additional property <key> is not allowed
```

This is intentional: silent ignores were the failure mode of earlier versions where operators kept stale overrides without realising they had no effect. The schema error makes the migration loud.

## Migration Steps

For every midaz deployment, before upgrading to `9.0.0`:

1. Inspect your values for `otel-collector-lerian:` block. Identify which scenario applies:
   - **You had `enabled: false, external: true`**: change to `enabled: true`. Remove `external`.
   - **You had `enabled: true`** (subchart installed inside midaz): install `otel-collector-lerian` as a standalone Helm release **first**, with the same values you had under the `otel-collector-lerian:` umbrella key. Then upgrade midaz with `otel-collector-lerian.enabled: true` and remove all subchart overrides.
   - **You had `enabled: false, external: false`** (no telemetry): no action required; the new chart still respects `enabled: false`.
   - **You had `external: true` but with custom subchart overrides** (`extraEnvs`, `exporters`, etc.): move those overrides to a standalone `otel-collector-lerian` release values file. Set midaz to `enabled: true` (or `false` with explicit configmap endpoint, see Breaking Change 4).
2. Remove any stale `extraEnvs`, `exporters`, `opentelemetry-collector`, or `external` keys from `otel-collector-lerian:` in your midaz values. If you leave them, the schema validation will fail on upgrade.
3. Run `helm template ... --debug` against your new values to confirm the schema accepts them before the actual upgrade.
4. If installing/keeping a standalone collector: do that first (`helm upgrade --install otel-collector-lerian ...`). Then upgrade midaz.
5. After upgrade, confirm midaz pods have OTEL env vars wired correctly:

   ```bash
   kubectl get pods -l app=ledger -o jsonpath='{.items[*].spec.containers[*].env[?(@.name=="OTEL_EXPORTER_OTLP_ENDPOINT")].value}'
   ```

   Should print `$(HOST_IP):4317` for every pod when `enabled: true`.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version <new-version> -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

Expected diff highlights:

- `otel-collector-lerian` subchart resources (DaemonSet, ConfigMap, etc.) **removed** from the release if you had `enabled: true` pre-9.0.0.
- `OTEL_RESOURCE_ATTRIBUTES=k8s.pod.ip=$(POD_IP)` and `POD_IP` env vars **added** to the `ledger` and `crm` deployments when `enabled: true`.

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version <new-version> -n midaz
```
