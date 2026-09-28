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

The previous logic had ambiguous behavior when both `minAvailable` and `maxUnavailable` were set. The new logic:

1. **Prioritizes `minAvailable`** if explicitly set by the operator
2. **Falls back to `maxUnavailable`** if `minAvailable` is not set
3. **Provides a safe default** (`maxUnavailable: 1`) if `maxUnavailable` is also undefined or invalid

This ensures predictable PDB behavior and prevents misconfigurations that could block cluster maintenance operations.

#### Operational impact

For most operators, **no action is required**. The default behavior remains:

```yaml
spec:
  maxUnavailable: 1
```

This allows one pod to be unavailable during rolling updates or node drains, which is appropriate for most deployments.

#### Migration scenarios

##### Scenario 1: You use default values (no customization)

**No action required.** The upgrade will apply `maxUnavailable: 1` for both services, which is the same effective behavior as before.

##### Scenario 2: You explicitly set `minAvailable` in your values

If you have customized `minAvailable` in your `values.yaml`:

```yaml
ledger:
  pdb:
    minAvailable: 2
```

**Action required:** The field still works, but you must now explicitly set it in your values override since it's no longer in the default values:

```yaml
ledger:
  pdb:
    minAvailable: 2
    # maxUnavailable will be ignored when minAvailable is set
```

> **Important:** When `minAvailable` is set, `maxUnavailable` is completely ignored. This is standard Kubernetes PDB behavior.

##### Scenario 3: You explicitly set `maxUnavailable` in your values

If you have customized `maxUnavailable`:

```yaml
crm:
  pdb:
    maxUnavailable: 2
```

**No action required.** This will continue to work as expected. Just ensure you don't also set `minAvailable`, as it would take precedence.

##### Scenario 4: You set both `minAvailable` and `maxUnavailable`

**Before v9.2.15:** The behavior was unpredictable depending on which value was set.

**After v9.2.15:** `minAvailable` always takes precedence. If you have both set:

```yaml
ledger:
  pdb:
    minAvailable: 2
    maxUnavailable: 1  # This will be ignored
```

**Action required:** Review your configuration and remove one of the fields to make your intent explicit:

```yaml
# Option 1: Use minAvailable (guarantees minimum pods always available)
ledger:
  pdb:
    minAvailable: 2

# Option 2: Use maxUnavailable (allows up to N pods to be unavailable)
ledger:
  pdb:
    maxUnavailable: 1
```

> **Note:** For high-availability deployments with 3+ replicas, `minAvailable` is typically preferred. For smaller deployments, `maxUnavailable: 1` is usually sufficient.

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
