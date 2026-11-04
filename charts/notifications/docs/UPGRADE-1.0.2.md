<!-- {% raw %} -->
# Helm Upgrade from v1.0.1 to v1.0.2

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Overview

This guide covers the `notifications` chart upgrade from `1.0.1` to `1.0.2`. This is a **patch** release. It needs no values change and no action before or after the upgrade. The application version (`appVersion: "1.1.0"`) remains unchanged.

Every pod of the release restarts once during this upgrade.

## Changes

### Pod templates no longer carry the `helm.sh/chart` label

The pod templates of the `api`, `worker-email`, `worker-sms` and `worker-webhook` Deployments no longer carry the `helm.sh/chart` label. The label contains the chart version, so every chart release changed the pod template and restarted the pods, even when nothing else changed.

- The label stays on the metadata of every resource, including the Deployments.
- Selectors are unchanged.
- The pod template change makes Kubernetes roll each Deployment once on this upgrade. Later chart releases do not restart pods only because the chart version changed.

## Migration Steps

No step is required.

> **Note:** The commands in this guide use the release name `notifications` and the namespace `notifications`. They are examples. Replace them with the values you used at install time.

## Preview changes before upgrading

```bash
helm diff upgrade notifications oci://registry-1.docker.io/lerianstudio/notifications-helm --version 1.0.2 -n notifications
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade notifications oci://registry-1.docker.io/lerianstudio/notifications-helm --version 1.0.2 -n notifications
```

## Verify

```bash
kubectl get pods -n notifications -l app.kubernetes.io/instance=notifications
```

All pods must reach `Running` and `Ready` after the one restart. The `helm.sh/chart` label no longer shows on them:

```bash
kubectl get pods -n notifications -l app.kubernetes.io/instance=notifications --show-labels
```
<!-- {% endraw %} -->
