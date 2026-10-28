<!-- {% raw %} -->
# Helm Upgrade from v10.0.0 to v10.0.1

## Topics

- **[Fixes](#fixes)**
  - [1. Tolerations field type correction](#1-tolerations-field-type-correction)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Tolerations field type correction

The `tolerations` field for `ledger`, `crm`, and `tracer` services has been corrected from an empty object (`{}`) to an empty array (`[]`). This aligns with the Kubernetes API specification, which requires `tolerations` to be an array of toleration objects.

#### What changed

| Service | Setting | v10.0.0 | v10.0.1 |
|---------|---------|---------|---------|
| ledger | tolerations | `{}` | `[]` |
| crm | tolerations | `{}` | `[]` |
| tracer | tolerations | `{}` | `[]` |

**Before (v10.0.0):**

```yaml
ledger:
  tolerations: {}

crm:
  tolerations: {}

tracer:
  tolerations: {}
```

**After (v10.0.1):**

```yaml
ledger:
  tolerations: []

crm:
  tolerations: []

tracer:
  tolerations: []
```

#### Why this matters

- **Kubernetes API compliance**: The `tolerations` field in pod specifications must be an array, not an object. While an empty object may have been silently ignored or caused validation warnings, the correct type is an array.
- **Template compatibility**: Helm templates that iterate over tolerations (e.g., `{{- with .Values.ledger.tolerations }}` or `{{- range .Values.ledger.tolerations }}`) expect an array structure.
- **Prevents potential errors**: Using the correct type prevents potential issues when adding tolerations in the future or when Kubernetes API validation becomes stricter.

#### Operational impact

For deployments using the default values (empty tolerations), this change has **no functional impact** on running pods. Both `{}` and `[]` result in no tolerations being applied. The rendered pod specification remains identical:

```yaml
spec:
  tolerations: []
```

If your values file explicitly sets tolerations as an array (the correct format), this change also has no impact:

```yaml
ledger:
  tolerations:
    - key: "workload"
      operator: "Equal"
      value: "ledger"
      effect: "NoSchedule"
```

#### Action required

##### Scenario 1: You use default values or already use array syntax

**No action required.** The upgrade will apply the corrected default, and your existing toleration configurations will continue to work.

##### Scenario 2: Your values file contains `tolerations: {}`

If your custom values file explicitly sets `tolerations: {}` (copied from the old chart defaults), you should update it to use the correct array syntax:

**Before:**

```yaml
ledger:
  tolerations: {}
```

**After:**

```yaml
ledger:
  tolerations: []
```

> **Note:** While leaving `tolerations: {}` in your values may still work due to Helm's merge behavior, updating to `[]` ensures consistency with Kubernetes API standards and the chart's new defaults.

##### Scenario 3: Adding tolerations after upgrade

When adding tolerations, always use array syntax:

```yaml
ledger:
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "ledger-workload"
      effect: "NoSchedule"
    - key: "high-memory"
      operator: "Exists"
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

After upgrading, verify that tolerations are correctly applied (or absent) in your pod specifications:

```bash
kubectl get pod -n midaz -l app.kubernetes.io/component=ledger -o jsonpath='{.items[0].spec.tolerations}'
kubectl get pod -n midaz -l app.kubernetes.io/component=crm -o jsonpath='{.items[0].spec.tolerations}'
kubectl get pod -n midaz -l app.kubernetes.io/component=tracer -o jsonpath='{.items[0].spec.tolerations}'
```

If you have configured custom tolerations, verify they appear in the output. If using defaults, the output should be `[]` or empty.

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
