# Helm Upgrade from v9.2.14 to v9.2.15

## Topics

- **[Fixes](#fixes)**
  - [1. PodDisruptionBudget configuration logic improved](#1-poddisruptionbudget-configuration-logic-improved)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. PodDisruptionBudget configuration logic improved

The PodDisruptionBudget (PDB) template logic for both `ledger` and `crm` services has been refactored to provide more predictable behavior and better handling of edge cases.

#### What changed

**Values.yaml changes:**

The `minAvailable` field has been removed from the default configuration for both services, and the comment for `maxUnavailable` has been updated to clarify precedence:

| Service | Setting | v9.2.14 | v9.2.15 |
|---------|---------|---------|---------|
| ledger | pdb.minAvailable | `1` (default) | removed |
| ledger | pdb.maxUnavailable | `1` | `1` |
| crm | pdb.minAvailable | `0` (default) | removed |
| crm | pdb.maxUnavailable | `1` | `1` |

**Before (v9.2.14):**

```yaml
ledger:
  pdb:
    enabled: true
    # -- Minimum number of available pods
    minAvailable: 1
    # -- Maximum number of unavailable pods
    maxUnavailable: 1
```

```yaml
crm:
  pdb:
    enabled: true
    # -- Minimum number of available pods
    minAvailable: 0
    # -- Maximum number of unavailable pods
    maxUnavailable: 1
```

**After (v9.2.15):**

```yaml
ledger:
  pdb:
    enabled: true
    # -- Maximum number of unavailable pods; ignored when minAvailable is set.
    maxUnavailable: 1
```

```yaml
crm:
  pdb:
    enabled: true
    # -- Maximum number of unavailable pods; ignored when minAvailable is set.
    maxUnavailable: 1
```

**Template logic changes:**

The PDB template logic has been rewritten to follow a clear precedence order:

**Before (v9.2.14):**

```yaml
spec:
  {{- with .Values.ledger.pdb.maxUnavailable }}
  maxUnavailable: {{ . }}
  {{- else }}
  minAvailable: {{ .Values.ledger.pdb.minAvailable | default 1 }}
  {{- end }}
```

**After (v9.2.15):**

```yaml
spec:
  {{- if .Values.ledger.pdb.minAvailable }}
  minAvailable: {{ .Values.ledger.pdb.minAvailable }}
  {{- else if kindIs "invalid" .Values.ledger.pdb.maxUnavailable }}
  maxUnavailable: 1
  {{- else }}
  maxUnavailable: {{ .Values.ledger.pdb.maxUnavailable }}
  {{- end }}
```

#### Why this matters

Until v9.2.14, `ledger.pdb.minAvailable` and `crm.pdb.minAvailable` were **silently ignored**: the template rendered `maxUnavailable` whenever it was non-zero, and the chart default was `maxUnavailable: 1`, so `minAvailable` only applied if you also set `maxUnavailable` to `0` or `null`. From v9.2.15 a non-zero `minAvailable` is rendered and `maxUnavailable` is ignored:

1. **Prioritizes `minAvailable`** when it is set to a non-zero value
2. **Falls back to `maxUnavailable`** if `minAvailable` is not set
3. **Provides a default** (`maxUnavailable: 1`) if `maxUnavailable` is also unset or `null`

#### Operational impact

With the chart defaults, the rendered PDBs do not change:

```yaml
spec:
  maxUnavailable: 1
```

If your values set `minAvailable`, this upgrade **changes the rendered PDB** from `maxUnavailable` to `minAvailable`. When `minAvailable` is equal to or greater than the number of running pods, the PDB allows zero disruptions and `kubectl drain` (cluster upgrades, node rotation, autoscaler scale-down) can no longer evict those pods. Examples: `crm.pdb.minAvailable: 1` with the default `crm.replicaCount: 1`, or `ledger.pdb.minAvailable: 1` with `ledger.replicaCount: 1`.

#### Migration scenarios

##### Scenario 1: You use default values (no customization)

**No action required.** The upgrade renders `maxUnavailable: 1` for both services, as before.

##### Scenario 2: Your values set `minAvailable`

This includes values files copied from the chart's full `values.yaml`, which listed `ledger.pdb.minAvailable: 1` and `crm.pdb.minAvailable: 0` next to `maxUnavailable: 1`.

| Your values | v9.2.14 renders | v9.2.15 renders |
|-------------|-----------------|-----------------|
| `minAvailable: 1`, `maxUnavailable: 1` | `maxUnavailable: 1` | `minAvailable: 1` |
| `minAvailable: 2` (with the default `maxUnavailable: 1`) | `maxUnavailable: 1` | `minAvailable: 2` |
| `minAvailable: 0`, `maxUnavailable: 1` | `maxUnavailable: 1` | `maxUnavailable: 1` |

**Action required:** Before upgrading, decide which budget you want and keep only that key. To keep the behavior you had in v9.2.14, remove `minAvailable`:

```yaml
ledger:
  pdb:
    maxUnavailable: 1
```

Keep `minAvailable` only if it is lower than the replica count that is always running (`replicaCount`, or `autoscaling.minReplicas` when the HPA is enabled):

```yaml
ledger:
  replicaCount: 3
  pdb:
    minAvailable: 2
```

##### Scenario 3: Your values set only `maxUnavailable`

```yaml
crm:
  pdb:
    maxUnavailable: 2
```

**No action required.** This renders exactly as before.
#### Verification after upgrade

After upgrading, verify your PDB configuration:

```bash
kubectl get pdb -n midaz
kubectl describe pdb midaz-ledger -n midaz
kubectl describe pdb midaz-crm -n midaz
```

Check that the `Min Available` or `Max Unavailable` field matches your intended configuration.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.15 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.15 -n midaz
```
