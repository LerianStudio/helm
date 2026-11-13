<!-- {% raw %} -->
# Helm Upgrade from v2.1.0 to v2.2.0

`streaming-hub` 2.2.0 ships Streaming Hub 3.4.0 and moves probes, drain and the disruption budget to the `lerian-common` health preset. The Hub serves `/health`, `/readyz` and `/metrics` on the internal health port 8099 (`HEALTH_PORT`). Upgrade the chart and the image together: the chart refuses an `image.tag` below `3.3.0` (explicit, or inherited from `appVersion`), and Hub 3.3.0 or later no longer serves `/healthz`, so the old probes would return 404 on the new image.

## What changes

| Area | Before (2.1.0, Hub 3.1.0) | After (2.2.0, Hub 3.4.0) |
|---|---|---|
| Probes | liveness `/healthz`, readiness `/readyz` on port `http` 8080, tunable | startup and liveness `/health`, readiness `/readyz`, port `health` (8099); not values |
| Container ports | `http` 8080 | plus `health` 8099 |
| Service | `http` 8080 | plus ClusterIP port `health` 8099 (never routed by an Ingress); 8080 is unchanged |
| Env | none | `HEALTH_PORT=8099`, `SHUTDOWN_DRAIN_DELAY=15s`, `SHUTDOWN_TIMEOUT=30s` |
| Grace period | `terminationGracePeriodSeconds: 90` | computed: drain 15 + shutdown 30 + 10 = 55s |
| Rollout | `maxSurge: 1`, `maxUnavailable: 0` | `maxSurge: 25%`, `maxUnavailable: 0` |
| Replicas per role | 1 | 2 (HPA `minReplicas` 2) |
| PDB | off by default, `pdb` values | always rendered per role: `maxUnavailable: 1`, `unhealthyPodEvictionPolicy: AlwaysAllow` |
| Metrics | `/metrics` on 8080 (only `streaming_hub_build_info`) | `/metrics` on 8099 (`health_check_status`, `health_ready`) |

The main port 8080 now serves `/health` (always 200), `/version`, `/runtime`, `/v1`, `/admin` and `/system`. `/healthz`, `/readyz` and `/metrics` are gone from it. Until the Hub finishes starting, `/v1` answers 503 with `Retry-After: 5`.

## Remove from your values

The render or the schema refuses these keys, so delete them in the same change that bumps the chart:

- `streamingHub.livenessProbe`, `streamingHub.readinessProbe` and `streamingHub.terminationGracePeriodSeconds` (the render fails);
- `streamingHub.configmap.STREAMING_HUB_SHUTDOWN_TIMEOUT` and `streamingHub.configmap.STREAMING_HUB_PRE_STOP_DRAIN_TIMEOUT` (the schema refuses them; Hub 3.4.0 ignores both). Use `streamingHub.health.shutdownSeconds` (default 30, at most 34: the Hub refuses to boot at 35s or more) and `streamingHub.health.drainSeconds` (default 15);
- `streamingHub.deploymentStrategy` and `streamingHub.<role>.pdb` are no longer read (silently ignored).

`ORGANIZATION_IDS` and `IS_DEVELOPMENT` are no longer read by the Hub or rendered by the chart. Setting them is still accepted, and the old "must be `global`" render check is gone.

A `--reuse-values` upgrade from 2.1.0 carries the removed keys and fails the render; upgrade with your values file instead.

```diff
 streamingHub:
-  terminationGracePeriodSeconds: 120
-  livenessProbe:
-    periodSeconds: 20
-  readinessProbe:
-    periodSeconds: 10
-  configmap:
-    STREAMING_HUB_SHUTDOWN_TIMEOUT: "30s"
-    STREAMING_HUB_PRE_STOP_DRAIN_TIMEOUT: "5s"
+  health:
+    drainSeconds: 15
+    shutdownSeconds: 30
```

## Before you upgrade

1. **Database migrations.** Hub 3.4.0 needs schema version 46; 3.1.0 ran at 44. Migrations 000045 (delegated registry status) and 000046 (drops the unused license table) are new. The migrations Job is off by default (`streamingHub.migrations.enabled: false`), and the Hub never migrates itself. Run them before the rollout (enable the Job, or apply them with your own tooling). Until the database reaches 46 the new pods stay running but not ready, with ingest, dispatch and crons idle. A database already at 46 does not disturb old pods.
2. **Console pairing.** Console 3.3.0 and later checks `GET /health` on the Hub service at port 8080; Console 3.2.x checks `/healthz`. Hub 3.3.0+ with Console 3.2.x, or Console 3.3.0+ with a Hub older than 3.3.0, shows CNS-0012 ("The service answered with an error.") when enabling the Streaming Hub. Upgrade the Hub and the Console together, Console 3.3.0 or later.
3. **License.** Hub 3.4.0 validates a signed license file (lib-license-go v5). With `LICENSE_KEY`, the pod needs egress to `https://license.lerian.io` at every boot. While the server is unreachable the pod stays up but not ready (8080 closed) and is not restarted; a refused key exits the pod. Without access to the license server, mount a signed license file with `streamingHub.licenseFile.existingSecret` (Secret key `license`, mounted as a directory at `/etc/lerian/license`); the chart sets `LICENSE_FILE_PATH`, which wins over `LICENSE_KEY`.
4. **BYOC network policy.** The kubelet probes the pod on 8099 now. A policy that admits only 8080 must also admit the node to 8099.
5. **Load balancer and uptime checks.** A check on `/healthz`, `/readyz` or `/metrics` on 8080 returns 404. Point it at `/health` on 8080 (the chart forces this on an ALB Ingress). Never route an Ingress to 8099.
6. **Scraping.** Point Prometheus at the pod's port 8099 `/metrics`, inside the cluster.
7. **Footprint.** Each role now runs 2 replicas, so Postgres connections double; check Σ(replicas x `poolMaxOpenConns`) against `max_connections`. The PDB needs Kubernetes 1.27 or later (`unhealthyPodEvictionPolicy`).
8. **Readiness behavior.** `/readyz` latches after the first success: a later Postgres or Kafka outage is reported but does not pull the pod from the Service. The pod no longer flips NotReady on SIGTERM; it keeps serving for the 15s drain delay. In the `all` and `ingest` roles `/health` answers 503 if the consumer has exited, so liveness restarts the pod.

## Rollback

Roll back the chart and the image together. An image-tag-only rollback below `3.3.0` fails the render and the running version stays. The database stays at 46, which the older Hub accepts.

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm --version 2.2.0 -n streaming-hub -f <your-values>.yaml
```

## Command to upgrade

```bash
helm upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm --version 2.2.0 -n streaming-hub -f <your-values>.yaml
```
<!-- {% endraw %} -->
