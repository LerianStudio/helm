# Helm Upgrade from v10.0.1 to v10.0.2

## Topics

- **[Fixes](#fixes)**
  - [1. Empty map accepted again for tolerations](#1-empty-map-accepted-again-for-tolerations)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Empty map accepted again for tolerations

This release changes `values.schema.json` only (plus the chart version in `Chart.yaml`). The templates, `values.yaml` defaults and `appVersion` (`4.3.0`) do not change.

#### What changed

v10.0.1 made the schema for `ledger.tolerations`, `crm.tolerations` and `tracer.tolerations` accept only an array. Values files written for v10.0.0 that set `tolerations: {}` then failed validation:

```text
Error: values don't meet the specifications of the schema(s) in the following chart(s):
- at '/ledger/tolerations': got object, want array
```

v10.0.2 accepts either form for these three fields:

| Value | v10.0.1 | v10.0.2 |
|-------|---------|---------|
| `[]` or a list of tolerations | accepted | accepted |
| `{}` (empty map) | rejected | accepted |
| a map with keys, such as `{foo: bar}` | rejected | rejected |

The default in `values.yaml` stays `[]`.

#### Operational impact

- The rendered resources change only in the chart version label. The templates only emit a `tolerations` block when the value is not empty, so tolerations stay as they were.
- Pods roll once. The chart version is part of the `helm.sh/chart` label in the pod templates, so any chart version bump, including this one, triggers a rolling restart of the Midaz pods.
- The ledger migrations Job runs as a `pre-upgrade` hook on every upgrade, including this one.
- Helm may print a warning such as `destination for midaz-helm.ledger.tolerations is a table. Ignoring non-table value ([])` when your values set `{}`. The warning does not stop the upgrade and the result renders without tolerations.

#### Action required

- If you stayed on v10.0.0 because v10.0.1 rejected `tolerations: {}`, you can upgrade to v10.0.2 without editing your values.
- Optional: change `tolerations: {}` to `tolerations: []` in your values file to remove the warning.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.2 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.2 -n midaz
```
