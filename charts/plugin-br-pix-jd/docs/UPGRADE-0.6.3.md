# Helm Upgrade from v0.6.2 to v0.6.3

## Topics

- **[Overview](#overview)**
- **[What Changed](#what-changed)**
- **[Migration Impact](#migration-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Overview

This is a patch release that updates the `plugin-br-pix-jd` chart from version 0.6.2 to 0.6.3. The application version stays at 1.6.1 and no image tag changes.

| Setting | v0.6.2 | v0.6.3 |
|---------|--------|--------|
| Chart Version | 0.6.2 | 0.6.3 |
| App Version | 1.6.1 | 1.6.1 |
| API Image Tag | 1.6.1 | 1.6.1 |
| Worker Image Tag | 1.6.1 | 1.6.1 |
| Migrations Image Tag | 1.6.1 | 1.6.1 |

## What Changed

1. **Pod templates no longer carry the `helm.sh/chart` label.** The API Deployment, the worker Deployment and the migrations Job set this label on their pods. It changed on every chart release, so every release restarted the pods. It stays on the other chart objects. Selectors do not change.
2. **Example in a render error.** The error shown when `STREAMING_ENABLED=true` and `STREAMING_BROKERS` is empty now uses `redpanda.example.com:9092` as the example broker list.
3. **Chart metadata.** `Chart.yaml` `sources` lists only the chart path in this repository.

No value is added, removed or renamed.

## Migration Impact

**No configuration changes required.** Apply this upgrade directly to v0.6.2 installations with your existing values.

The pod-template label change alters the pod templates, so the API and worker pods restart once during this upgrade. From this release on, a chart version bump alone does not change the pod templates. Plan the upgrade as you plan any rollout of these pods.

The migrations Job runs as in v0.6.2 (same image, same hook phase).

## Preview changes before upgrading

```bash
helm diff upgrade <pix-release> oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.6.3 -n midaz-plugins -f my-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade <pix-release> oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm --version 0.6.3 -n midaz-plugins -f my-values.yaml
```

Replace `<pix-release>` with your release name.

If you set the payment signing key and certificate with `--set-file`, add the same two `--set-file` flags to these commands. Otherwise the upgrade drops them and payment orders go out unsigned.

## Verify

```bash
kubectl -n midaz-plugins get pods -l app.kubernetes.io/component=api
kubectl -n midaz-plugins get pods -l app.kubernetes.io/component=worker
```

All pods must reach `Running` and `Ready`. The chart label is no longer on the pods; the Deployments and other objects still carry `helm.sh/chart: plugin-br-pix-jd-helm-0.6.3`.
