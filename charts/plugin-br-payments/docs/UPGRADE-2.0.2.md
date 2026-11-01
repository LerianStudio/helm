<!-- {% raw %} -->
# Helm Upgrade from v2.0.1 to v2.0.2

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Startup probe configuration](#1-startup-probe-configuration)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.0.1` to `2.0.2`. The application version remains `1.0.2`; the chart bump to `2.0.2` is a patch release that introduces a startup probe configuration to the application deployment. The startup probe prevents premature liveness and readiness checks during long-running database migrations, reducing the risk of pod restarts during initialization.

This upgrade requires no operator action beyond running the upgrade command. Existing deployments will continue to work without values changes. The new startup probe is configured with sensible defaults that cover typical boot and migration times.

## Features

### 1. Startup probe configuration

The deployment template now includes a `startupProbe` that gates the liveness and readiness probes until the application has completed its initialization sequence. The probe is configured to allow up to 400 seconds (40 failures × 10 second period) for the application to start, which covers the default database connection timeout (30 seconds) plus the default migration timeout (`MIGRATION_TIMEOUT_SEC`, 300 seconds).

**Why this matters:**

The `plugin-br-payments` application runs database migrations on startup. If migrations take longer than the liveness probe's `initialDelaySeconds` + `failureThreshold` × `periodSeconds`, Kubernetes will restart the pod before migrations complete, causing a restart loop. The startup probe delays liveness and readiness checks until the application signals it is ready, preventing premature restarts.

**Before (v2.0.1):**

No startup probe was configured. The deployment relied solely on `readinessProbe.initialDelaySeconds` and `livenessProbe.initialDelaySeconds` to avoid premature health checks.

**After (v2.0.2):**

The deployment template includes a startup probe with configurable period, timeout, and failure threshold:

```yaml
startupProbe:
  httpGet:
    path: /health
    port: http
  periodSeconds: {{ ($.Values.app.startupProbe | default dict).periodSeconds | default 10 }}
  timeoutSeconds: {{ ($.Values.app.startupProbe | default dict).timeoutSeconds | default 3 }}
  failureThreshold: {{ ($.Values.app.startupProbe | default dict).failureThreshold | default 40 }}
```

The corresponding `values.yaml` section:

```yaml
app:
  # -- Startup probe: failureThreshold x periodSeconds must cover boot (connect 30s +
  # MIGRATION_TIMEOUT_SEC, default 300s). Raise it if you raise MIGRATION_TIMEOUT_SEC.
  startupProbe:
    periodSeconds: 10
    timeoutSeconds: 3
    failureThreshold: 40
```

**Operational impact:**

- **Default behavior:** The startup probe allows up to 400 seconds for the application to start. During this window, Kubernetes will not execute liveness or readiness probes. Once the startup probe succeeds (the `/health` endpoint returns a successful response), the liveness and readiness probes take over.
- **Custom migration timeouts:** If you have set a custom `MIGRATION_TIMEOUT_SEC` environment variable greater than 300 seconds, you must increase `app.startupProbe.failureThreshold` to ensure `failureThreshold × periodSeconds` exceeds `30 + MIGRATION_TIMEOUT_SEC`. For example, if `MIGRATION_TIMEOUT_SEC=600`, set `failureThreshold: 70` (70 × 10 = 700 seconds).
- **Faster startups:** If your migrations consistently complete in under 100 seconds, you may reduce `failureThreshold` to fail faster on genuine startup failures.

**Startup probe configuration:**

| Flag | Default | Description |
|------|---------|-------------|
| `app.startupProbe.periodSeconds` | `10` | How often (in seconds) to perform the startup probe |
| `app.startupProbe.timeoutSeconds` | `3` | Number of seconds after which the probe times out |
| `app.startupProbe.failureThreshold` | `40` | Number of consecutive failures before the pod is restarted |

> **Note:** The startup probe uses the same `/health` endpoint as the readiness and liveness probes. The application must return a successful HTTP response on this endpoint once it has completed migrations and is ready to serve traffic.

> **Important:** If you override `MIGRATION_TIMEOUT_SEC` in your values overlay, ensure `app.startupProbe.failureThreshold × app.startupProbe.periodSeconds` is greater than `30 + MIGRATION_TIMEOUT_SEC`. Otherwise, the pod may restart before migrations complete.

## Configuration Changes

| Setting | v2.0.1 | v2.0.2 |
|---------|--------|--------|
| `app.startupProbe` | not set | `periodSeconds: 10, timeoutSeconds: 3, failureThreshold: 40` |
| `app.startupProbe.periodSeconds` | n/a | `10` |
| `app.startupProbe.timeoutSeconds` | n/a | `3` |
| `app.startupProbe.failureThreshold` | n/a | `40` |

No other configuration values were added, removed, or changed. The readiness and liveness probe configurations remain unchanged.

## Migration Steps

1. **(Optional)** If you have set a custom `MIGRATION_TIMEOUT_SEC` environment variable in `app.configmap` or `app.secrets`, calculate the required startup probe window:

   ```
   Required window = 30 seconds (connection timeout) + MIGRATION_TIMEOUT_SEC
   Required failureThreshold = ceil(Required window / periodSeconds)
   ```

   For example, if `MIGRATION_TIMEOUT_SEC=600`:

   ```
   Required window = 30 + 600 = 630 seconds
   Required failureThreshold = ceil(630 / 10) = 63
   ```

   Add the following to your values overlay:

   ```yaml
   app:
     startupProbe:
       failureThreshold: 63
   ```

2. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

3. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n <namespace>
   ```

4. Check the pod events to confirm the startup probe succeeded before the liveness probe began:

   ```bash
   kubectl describe pod -n <namespace> -l app.kubernetes.io/name=plugin-br-payments-helm
   ```

   Look for events indicating the startup probe passed, followed by liveness and readiness probe events.

5. **(Optional)** Monitor the startup probe duration in your first few deployments after the upgrade. If the probe consistently succeeds in under 200 seconds, consider reducing `failureThreshold` to fail faster on genuine startup issues:

   ```yaml
   app:
     startupProbe:
       failureThreshold: 20  # 20 × 10 = 200 seconds
   ```

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 2.0.2 -n plugin-br-payments
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-payments oci://registry-1.docker.io/lerianstudio/plugin-br-payments-helm --version 2.0.2 -n plugin-br-payments
```
<!-- {% endraw %} -->
