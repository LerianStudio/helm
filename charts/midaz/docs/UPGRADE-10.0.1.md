<!-- {% raw %} -->
# Helm Upgrade from v10.0.0 to v10.0.1

## Topics

- **[Breaking changes](#breaking-changes)**
  - [1. Tolerations field type changed from object to array](#1-tolerations-field-type-changed-from-object-to-array)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking changes

> **Warning:** If your values file sets `ledger.tolerations`, `crm.tolerations` or `tracer.tolerations` to `{}`, v10.0.1 rejects it and `helm upgrade` fails. Chart v10.0.2 accepts an empty map again. Upgrade to v10.0.2 or later, or change the value to `[]` before you use v10.0.1.

### 1. Tolerations field type changed from object to array

The chart now defines `tolerations` for the `ledger`, `crm` and `tracer` services as an array, the type Kubernetes uses for pod tolerations. The default in `values.yaml` changed from `{}` to `[]`. The `values.schema.json` type changed from `object` to `array`.

#### What changed

| Service | Setting | v10.0.0 default | v10.0.1 default | Schema type in v10.0.0 | Schema type in v10.0.1 |
|---------|---------|-----------------|-----------------|------------------------|------------------------|
| ledger | `ledger.tolerations` | `{}` | `[]` | object | array |
| crm | `crm.tolerations` | `{}` | `[]` | object | array |
| tracer | `tracer.tolerations` | `{}` | `[]` | object | array |

The `README.md` and `README.params.md` tables follow the new type.

#### What an operator sees

A values file that sets `tolerations: {}` for one of these services fails schema validation in v10.0.1:

```text
Error: values don't meet the specifications of the schema(s) in the following chart(s):
- at '/ledger/tolerations': got object, want array
```

The same error applies to `crm` and `tracer`. Chart v10.0.2 fixes this: its schema accepts an array or an empty map.

#### Operational impact

- Default values: the rendered tolerations do not change. The templates only emit a `tolerations` block when the value is not empty, so no `tolerations` key is rendered for `{}` or for `[]`.
- A non-empty array: the rendered tolerations are the same as before.
- Pods still roll once. The chart version is part of the `helm.sh/chart` label in the pod templates, so any chart version bump, including this one, triggers a rolling restart of the Midaz pods.
- The ledger migrations Job runs as a `pre-upgrade` hook on every upgrade, including this one.

#### Action required

##### Scenario 1: You use default values or already use array syntax

No action required.

##### Scenario 2: Your values file contains `tolerations: {}`

Change the value to an empty array, or skip v10.0.1 and upgrade to v10.0.2 or later.

Before:

```yaml
ledger:
  tolerations: {}
```

After:

```yaml
ledger:
  tolerations: []
```

##### Scenario 3: You add tolerations

Use array syntax:

```yaml
ledger:
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "ledger-workload"
      effect: "NoSchedule"

crm:
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "crm-workload"
      effect: "NoSchedule"

tracer:
  tolerations:
    - key: "monitoring"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
```

#### Verification after upgrade

Check the tolerations on the running pods:

```bash
kubectl get pod -n midaz -l app.kubernetes.io/name=midaz-ledger -o jsonpath='{.items[0].spec.tolerations}'
kubectl get pod -n midaz -l app.kubernetes.io/name=midaz-crm -o jsonpath='{.items[0].spec.tolerations}'
kubectl get pod -n midaz -l app.kubernetes.io/name=midaz-tracer -o jsonpath='{.items[0].spec.tolerations}'
```

Kubernetes adds its own default tolerations (`node.kubernetes.io/not-ready` and `node.kubernetes.io/unreachable`) to every pod. The output lists those plus the ones you configured. The `crm` and `tracer` commands return a result only when those services are enabled.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.0.1 -n midaz
```
<!-- {% endraw %} -->
