<!-- {% raw %} -->
# Helm Upgrade from v10.3.3 to v10.3.4

## Topics

- **[Changes](#changes)**
  - [1. Chart version removed from pod templates](#1-chart-version-removed-from-pod-templates)
  - [2. Tracer migrations Job gets a new name](#2-tracer-migrations-job-gets-a-new-name)
  - [3. Metadata only](#3-metadata-only)
- **[Action required](#action-required)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

## Changes

The default `ledger.image.tag` and `tracer.image.tag` (`4.4.0`) and the chart `appVersion` do not change in this release. No value is added, removed or renamed.

### 1. Chart version removed from pod templates

The `helm.sh/chart` label no longer appears on the pod templates of the ledger, CRM and tracer Deployments, both migrations Jobs, the partition CronJob and the partition reconcile Job. The label stays on the Deployments, Jobs and CronJobs themselves. Pod selectors do not change.

Because the label was part of the pod templates, later chart-only upgrades no longer change them. Pods restart once on this upgrade, following the usual rolling update.

### 2. Tracer migrations Job gets a new name

The tracer migrations Job name ends in a hash of its spec, so the label change gives it a new name once (for example `midaz-tracer-migrations-4.4.0-359afde9` becomes `midaz-tracer-migrations-4.4.0-187edf0a`). The Job runs once more on this upgrade. It is safe to repeat: the migration tool keeps its progress in the database. The ledger migrations Job keeps its name. This applies only when `tracer.enabled` is `true`.

### 3. Metadata only

`Chart.yaml` no longer lists the Midaz source repository, and two comments no longer link to documentation pages. They do not change what the chart deploys.

## Action required

No action is required before or after the upgrade.

## Preview changes before upgrading

Replace `midaz` (release name) and `-n midaz` (namespace) in the commands below with the values used at install time.

Pass the `values.yaml` you used at install with `-f` on both commands. Without `-f` or `--set`, `helm upgrade` reuses the values stored in the release. If you do not keep one, export it with `helm get values midaz -n midaz -o yaml > values.yaml`.

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.4 -n midaz -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.3.4 -n midaz -f values.yaml
```

## Verify

```bash
kubectl get pods -n midaz -l app.kubernetes.io/instance=midaz
kubectl rollout status deployment/midaz-ledger -n midaz
kubectl get jobs -n midaz -l app.kubernetes.io/instance=midaz
```

All pods reach `Running` and `Ready`, and the tracer migrations Job shows `Complete`.
<!-- {% endraw %} -->
