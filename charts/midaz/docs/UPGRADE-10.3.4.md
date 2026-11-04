<!-- {% raw %} -->
# Helm Upgrade from v10.3.3 to v10.3.4

## Topics

- **[Changes](#changes)**
  - [1. Chart version removed from pod templates](#1-chart-version-removed-from-pod-templates)
- **[Action required](#action-required)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Changes

The default `ledger.image.tag` and `tracer.image.tag` (`4.4.0`) and the chart `appVersion` do not change in this release. No value is added, removed or renamed.

### 1. Chart version removed from pod templates

The `helm.sh/chart` label no longer appears on the pod templates of the ledger, CRM and tracer Deployments, both migrations Jobs, the partition CronJob and the partition reconcile Job. The label stays on the Deployments, Jobs and CronJobs themselves. Pod selectors do not change.

Pods restart once on this upgrade, following the usual rolling update. Later chart-only upgrades no longer change the ledger pod template. Both migrations Jobs run as upgrade hooks, as on every upgrade.

## Action required

No action is required before or after the upgrade.

## Preview changes before upgrading

The commands below are examples. Replace `midaz` (release name) and `-n midaz` (namespace) with the values used at install time. The ledger Deployment keeps the name `midaz-ledger` whatever the release is called.

The release keeps its stored values, so the commands pass no `-f` or `--set`.

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.4 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.4 -n midaz
```

## Verify

```bash
kubectl get pods -n midaz -l app.kubernetes.io/instance=midaz
kubectl rollout status deployment/midaz-ledger -n midaz
helm status midaz -n midaz
```

All pods reach `Running` and `Ready`, and `helm status` shows `deployed`. A migrations Job is deleted when it succeeds. Only a failed one stays, and a failed one also makes `helm upgrade` fail.
<!-- {% endraw %} -->
