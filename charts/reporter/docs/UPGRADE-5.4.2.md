<!-- {% raw %} -->
# Helm Upgrade from v5.4.1 to v5.4.2

## Topics

- **[Overview](#overview)**
- **[Application behavior changes in 4.10.0](#application-behavior-changes-in-4100)**
  - [1. Business events leave only through Kafka](#1-business-events-leave-only-through-kafka)
  - [2. The license is no longer stored in MongoDB](#2-the-license-is-no-longer-stored-in-mongodb)
- **[Fixes](#fixes)**
  - [1. Application version bump to 4.10.0](#1-application-version-bump-to-4100)
  - [2. Kafka streaming support for business events](#2-kafka-streaming-support-for-business-events)
  - [3. CloudEvents source default fixed to "reporter"](#3-cloudevents-source-default-fixed-to-reporter)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that bumps the application version to `4.10.0` and adds the Kafka broker setting this version needs. App `4.10.0` publishes business events only through Kafka: the RabbitMQ events exchange (`reporter.events`) no longer receives any event. The chart also fixes the default CloudEvents source (`//lerian.reporter` to `reporter`), which made the app refuse to boot when streaming was on.

Read [Application behavior changes in 4.10.0](#application-behavior-changes-in-4100) before upgrading. With streaming on, consumers of the RabbitMQ events exchange must move to the Streaming Hub first.

| Field | v5.4.1 | v5.4.2 |
|-------|--------|--------|
| Chart version | `5.4.1` | `5.4.2` |
| App version | `4.9.0` | `4.10.0` |
| Manager image tag | `4.9.0` | `4.10.0` |
| Worker image tag | `4.9.0` | `4.10.0` |

## Application behavior changes in 4.10.0

### 1. Business events leave only through Kafka

App `4.10.0` publishes every business event of the manager and the worker only through Kafka, which the Streaming Hub reads and delivers. RabbitMQ stays only for the internal work queues (report generation, retries, DLQ). See the release note of [reporter#1059](https://github.com/LerianStudio/reporter/pull/1059).

- **Streaming on (`global.streaming.enabled: true`):** app `4.9.0` published these events to the RabbitMQ exchange `reporter.events` (`RABBITMQ_REPORT_EVENTS_EXCHANGE`). App `4.10.0` no longer publishes to that exchange. **Before upgrading, move every consumer bound to that exchange to a Streaming Hub subscription.** The chart still declares the exchange, but it receives nothing.
- **Streaming off (default):** nothing changes. Apps `4.9.0` and `4.10.0` publish no business event when streaming is off.
- **Pending events of the old pods:** outbox rows that the `4.9.0` pods wrote for the RabbitMQ targets (`*-events-rabbitmq`) end `INVALID` after their retries, about 50 minutes after the upgrade. The `streaming_outbox_replay_target_unknown_total` alert fires. Re-emit any regulatory approval among those events.
- **`STREAMING_TENANT_KAFKA` is removed:** multi-tenant installs always publish to per-tenant topics. The chart never rendered this variable, and app `4.10.0` ignores it if you set it yourself.

### 2. The license is no longer stored in MongoDB

App `4.10.0` no longer stores the license file ([reporter#1039](https://github.com/LerianStudio/reporter/pull/1039)). With `LICENSE_KEY`, the app validates the license online, keeps it in memory and renews it every 6 hours. With `manager.licenseFile` / `worker.licenseFile`, the app reads the mounted file, as before.

- **Collection removed:** at boot, the manager and the worker drop the `lerian_license_file` collection from the `MONGO_NAME` database (single-tenant mode). A failed drop only logs a warning and does not stop the boot.
- **License server unavailable:** with `LICENSE_KEY`, a pod that starts while the license server does not answer stays alive but not ready (`/readyz` fails) until the server answers. App `4.9.0` could start from the copy stored in MongoDB; app `4.10.0` has no copy.
- **During the upgrade:** the new manager pods need the license server. The manager Deployment uses `maxUnavailable: 0`, so a new pod that never becomes ready stops the rollout, and the `4.9.0` pods keep serving traffic. If the rollout does not finish, check the license logs of the new pods.
- **No license server dependency:** mount a license file (`manager.licenseFile` / `worker.licenseFile`) to start without the license server.

## Fixes

### 1. Application version bump to 4.10.0

The manager and worker image tags have been updated from `4.9.0` to `4.10.0`, and the chart `appVersion` field reflects this change.

| Component | v5.4.1 | v5.4.2 |
|-----------|--------|--------|
| `manager.image.tag` | `"4.9.0"` | `"4.10.0"` |
| `worker.image.tag` | `"4.9.0"` | `"4.10.0"` |
| Chart `appVersion` | `"4.9.0"` | `"4.10.0"` |

### 2. Kafka streaming support for business events

Application version `4.10.0` introduces direct Kafka publishing for all business events. The application now reads `STREAMING_KAFKA_BROKERS` to dial Kafka brokers, while `STREAMING_BROKERS` (from lib-streaming) is still validated as non-empty but never dialed.

A new helper template `reporter.streamingKafkaBrokers` has been added to emit `STREAMING_KAFKA_BROKERS` in each component's ConfigMap. The helper is invoked in both `manager/configmap.yaml` and `worker/configmap.yaml`.

**How it works:**

- **Single-tenant mode:** When `STREAMING_ENABLED` is `true` and `global.streaming.brokers` is set, the helper emits `STREAMING_KAFKA_BROKERS` with the value from `global.streaming.brokers`. The application dials this list and refuses to boot if streaming is enabled and the key is empty.
- **Multi-tenant mode:** When `MULTI_TENANT_ENABLED` is `true`, the Tenant Manager serves the brokers per tenant, and `STREAMING_KAFKA_BROKERS` is not emitted.
- **Escape hatch:** If `common.configmap.STREAMING_KAFKA_BROKERS` is set, it takes precedence and the helper emits nothing (the value is rendered by `reporter.commonConfigmapData`).
- **Component override:** If a component sets `STREAMING_KAFKA_BROKERS` via its own `configmap` or `extraEnvVars`, the helper emits nothing to avoid duplication.

**Operational impact:**

- If you have `global.streaming.enabled: true` and `global.streaming.brokers` set in your values, the manager and worker ConfigMaps will now include `STREAMING_KAFKA_BROKERS` with the same broker list. The application will dial these brokers to publish business events.
- If you are running in multi-tenant mode (`global.multiTenant.enabled: true`), no `STREAMING_KAFKA_BROKERS` key is emitted. The Tenant Manager serves the brokers per tenant.
- Chart `5.4.1` described `global.streaming.brokers` as validated but never dialled, so some installs set a placeholder there. App `4.10.0` dials this list. With an unreachable broker the app still boots, but events stay in the outbox and reach no consumer. Set the real broker list (plus TLS/SASL) before upgrading.
- The chart still renders `RABBITMQ_REPORT_EVENTS_EXCHANGE`. App `4.10.0` ignores it and no longer publishes to that exchange (see [Business events leave only through Kafka](#1-business-events-leave-only-through-kafka)).

**Example configuration for single-tenant Kafka streaming:**

```yaml
global:
  streaming:
    enabled: true
    brokers: "redpanda:9092"
```

This will emit:

```yaml
STREAMING_ENABLED: "true"
STREAMING_BROKERS: "redpanda:9092"
STREAMING_KAFKA_BROKERS: "redpanda:9092"
```

**Example escape-hatch override:**

```yaml
common:
  configmap:
    STREAMING_KAFKA_BROKERS: "kafka-cluster-1:9092,kafka-cluster-2:9092"
```

This will use the explicit override instead of `global.streaming.brokers`.

> **Important:** Application version `4.10.0` requires `STREAMING_KAFKA_BROKERS` to be non-empty when `STREAMING_ENABLED` is `true` in single-tenant mode. If you enable streaming without setting `global.streaming.brokers`, the application will refuse to boot.

### 3. CloudEvents source default fixed to "reporter"

The chart default for `STREAMING_CLOUDEVENTS_SOURCE` changes from `//lerian.reporter` to `reporter`. The chart renders this default only when streaming is on.

This fixes a boot failure. Since app `4.8.0`, reporter accepts only the source `reporter` and refuses to boot with any other value. With chart `5.4.0` or `5.4.1`, streaming on and no override, the chart rendered `//lerian.reporter`, so the manager and the worker did not start. App `4.10.0` keeps the same rule.

**Operational impact:**

- If you did not set `common.configmap.STREAMING_CLOUDEVENTS_SOURCE`, the chart now renders `reporter`, and installs with streaming on boot.
- If you set it to `"reporter"` to work around the old default, keep it or remove it.
- If you set it to any other value and streaming is on, the app refuses to boot. Set it to `"reporter"` or remove the override. With streaming off, the chart does not render this `common.configmap` key.
- The app checks the source whether or not streaming is on. A value set in `manager.configmap`, `worker.configmap` or `extraEnvVars` always reaches the app, so any value other than `reporter` there stops the app at boot, also with streaming off.

## Configuration Changes

No `values.yaml` keys were added, removed, or renamed. The changes are in template logic and default values only.

| Setting | v5.4.1 | v5.4.2 | Notes |
|---------|--------|--------|-------|
| `manager.image.tag` | `"4.9.0"` | `"4.10.0"` | Application version bump |
| `worker.image.tag` | `"4.9.0"` | `"4.10.0"` | Application version bump |
| `STREAMING_CLOUDEVENTS_SOURCE` (default) | `"//lerian.reporter"` | `"reporter"` | Fixes the boot failure with streaming on: app `>= 4.8.0` accepts only `reporter` |
| `STREAMING_KAFKA_BROKERS` (new) | Not emitted | Emitted from `global.streaming.brokers` in single-tenant mode | Application dials this list to publish events |

## Migration Steps

Read [Application behavior changes in 4.10.0](#application-behavior-changes-in-4100) first. Values changes are needed only in the cases of steps 3 and 4.

The upgrade restarts the manager Deployment (and the worker Deployment when KEDA is disabled). With the default KEDA ScaledJob, the image change updates the ScaledJob, and KEDA deletes the existing worker Jobs, **including Jobs that are generating a report**. Those reports are interrupted.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. If streaming is on, move every consumer of the RabbitMQ exchange `reporter.events` to a Streaming Hub subscription. After the upgrade, that exchange receives no event.

3. If you set `common.configmap.STREAMING_CLOUDEVENTS_SOURCE` (or the same key in `manager.configmap`, `worker.configmap` or `extraEnvVars`) to a value other than `"reporter"`, update the values file you pass with `-f`:

   ```yaml
   common:
     configmap:
       STREAMING_CLOUDEVENTS_SOURCE: "reporter"
   ```

   Or remove the override entirely to use the new default.

4. If streaming is on in single-tenant mode, set the real broker list. App `4.10.0` dials it, and refuses to boot when it is empty:

   ```yaml
   global:
     streaming:
       enabled: true
       brokers: "your-kafka-brokers:9092"
   ```

5. Run the upgrade command during a maintenance window, when no report is being generated. With the default KEDA ScaledJob, check that no worker Job is running:

   ```bash
   kubectl get jobs -n <namespace> -l scaledjob.keda.sh/name=reporter-worker
   ```

6. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n <namespace>
   ```

7. Check manager and worker logs to confirm Kafka connectivity:

   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
   # Worker, default KEDA ScaledJob (pods exist only while a report Job runs); with KEDA disabled use -l app.kubernetes.io/name=reporter-worker
   kubectl logs -n <namespace> -l scaledjob.keda.sh/name=reporter-worker --tail=50
   ```

8. Verify the ConfigMaps include the new `STREAMING_KAFKA_BROKERS` key (if streaming is on in single-tenant mode):

   ```bash
   kubectl get configmap -n <namespace> reporter-manager -o jsonpath='{.data.STREAMING_KAFKA_BROKERS}'
   kubectl get configmap -n <namespace> reporter-worker -o jsonpath='{.data.STREAMING_KAFKA_BROKERS}'
   ```

> **Note:** With the default KEDA ScaledJob, KEDA creates new worker Jobs with the `4.10.0` image when new report messages arrive. If a report was being generated during the upgrade, check its status after the upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n <namespace> --version 5.4.2 -f <your-values>.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n <namespace> --version 5.4.2 -f <your-values>.yaml
```

> **Note:** Pass the same values files and `--set` / `--set-file` flags you used at install. Without `-f`, Helm reuses the stored values, and the changes from the migration steps do not apply. With `-f` but without the `--set` / `--set-file` flags, Helm drops those values.
<!-- {% endraw %} -->
