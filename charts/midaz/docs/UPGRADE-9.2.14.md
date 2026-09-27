# Helm Upgrade from v9.2.13 to v9.2.14

## Topics

- **[Fixes](#fixes)**
  - [1. Tracer PodDisruptionBudget default strategy change](#1-tracer-poddisruptionbudget-default-strategy-change)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Tracer PodDisruptionBudget default strategy change

The default PodDisruptionBudget (PDB) strategy for the tracer component has been changed from `minAvailable: 1` to `maxUnavailable: 1`. This change provides more flexibility during node drains and rolling updates by allowing Kubernetes to determine how many pods can remain available based on the total replica count, rather than enforcing a fixed minimum.

#### What changed

| Setting | v9.2.13 | v9.2.14 |
|---------|---------|---------|
| `tracer.pdb.minAvailable` | `1` (default) | removed (no default) |
| `tracer.pdb.maxUnavailable` | not set | `1` (default) |

#### Template logic changes

**Before (v9.2.13):**

```yaml
spec:
  {{- if hasKey .Values.tracer.pdb "maxUnavailable" }}
  maxUnavailable: {{ .Values.tracer.pdb.maxUnavailable }}
  {{- else if hasKey .Values.tracer.pdb "minAvailable" }}
  minAvailable: {{ .Values.tracer.pdb.minAvailable }}
  {{- else }}
  minAvailable: 1
  {{- end }}
```

**After (v9.2.14):**

```yaml
spec:
  {{- if .Values.tracer.pdb.minAvailable }}
  minAvailable: {{ .Values.tracer.pdb.minAvailable }}
  {{- else if kindIs "invalid" .Values.tracer.pdb.maxUnavailable }}
  maxUnavailable: 1
  {{- else }}
  maxUnavailable: {{ .Values.tracer.pdb.maxUnavailable }}
  {{- end }}
```

#### Why this matters

- **More flexible disruption handling**: With `maxUnavailable: 1`, Kubernetes can maintain availability based on your actual replica count. For example, with 3 replicas, 2 pods will always remain available during disruptions.
- **Better scaling behavior**: The `maxUnavailable` strategy scales better with different replica counts compared to a fixed `minAvailable` value.
- **Backward compatibility preserved**: If you explicitly set `minAvailable` in your values, it will continue to take precedence over `maxUnavailable`.

#### Migration options

#### Option 1: Accept the new default (recommended)

No action required. The new default `maxUnavailable: 1` will be applied automatically on upgrade. This is suitable for most deployments and provides better flexibility.

#### Option 2: Keep the previous behavior

If you need to maintain the exact previous behavior with `minAvailable: 1`, explicitly set it in your values:

```yaml
tracer:
  pdb:
    enabled: true
    minAvailable: 1
```

> **Note:** Setting `minAvailable` will override `maxUnavailable` in the template logic. You cannot use both settings simultaneously.

#### Option 3: Customize maxUnavailable

You can now explicitly configure `maxUnavailable` to a different value:

```yaml
tracer:
  pdb:
    enabled: true
    maxUnavailable: 2
```

> **Important:** Ensure your `maxUnavailable` value is appropriate for your replica count. Setting it too high may allow too many pods to be unavailable simultaneously.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.14 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.14 -n midaz
```
