<!-- {% raw %} -->
# Helm Upgrade from v1.1.0 to v1.1.1

## Topics

- **[Fixes](#fixes)**
  - [Graceful Shutdown Configuration](#graceful-shutdown-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### Graceful Shutdown Configuration

This release adds explicit graceful shutdown configuration to ensure the application has sufficient time to drain in-flight requests and shut down cleanly during pod termination.

| Setting | v1.1.0 | v1.1.1 |
|---------|--------|--------|
| `terminationGracePeriodSeconds` | Not set (Kubernetes default: 30s) | `55` |
| `SHUTDOWN_DRAIN_DELAY` environment variable | Not set | `15s` |

**What changed:**

The chart now sets:

1. **Pod termination grace period** (`terminationGracePeriodSeconds: 55`): Kubernetes waits 55 seconds after sending SIGTERM before forcefully killing the pod
2. **Container environment variable** (`SHUTDOWN_DRAIN_DELAY: 15s`): a fixed value in the container `env` of the Deployment.

**Why it matters:**

The 55-second grace period is calculated as:
- 15s drain delay (allow deregistration from load balancers)
- 30s shutdown budget (complete in-flight requests and close connections)
- 10s safety margin (prevent premature SIGKILL)

**Configuration:**

**After (v1.1.1):**
```yaml
plugin-br-ted-lerian:
  # -- Seconds Kubernetes waits after SIGTERM before killing the pod
  # 55 = 15s drain + 30s shutdown budget + 10s margin
  terminationGracePeriodSeconds: 55
```

**New environment variable:**
- `SHUTDOWN_DRAIN_DELAY`: set to `15s` in the container `env` by the chart template (not a values key).

**Template changes:**

**Before (v1.1.0):**
```yaml
spec:
  template:
    spec:
      containers:
        - name: plugin-br-ted-lerian
          envFrom:
          - secretRef:
              name: {{ if (index .Values "plugin-br-ted-lerian").useExistingSecret }}{{ (index .Values "plugin-br-ted-lerian").existingSecretName }}{{ else }}{{ include "plugin-br-ted-lerian.fullname" . }}{{ end }}
          - configMapRef:
              name: {{ include "plugin-br-ted-lerian.fullname" . }}
          {{- if or $otelEnabled $rolesAnywhereEnabled $pgInternal $vkInternal }}
          env:
          {{- if $pgInternal }}
          {{- include "plugin-br-ted-lerian.infraSecretRef" (dict "context" . "subchart" "postgresql" "key" "password" "envName" "POSTGRES_PASSWORD") | nindent 10 }}
          {{- end }}
```

**After (v1.1.1):**
```yaml
spec:
  template:
    spec:
      terminationGracePeriodSeconds: {{ (index .Values "plugin-br-ted-lerian").terminationGracePeriodSeconds }}
      containers:
        - name: plugin-br-ted-lerian
          envFrom:
          - secretRef:
              name: {{ if (index .Values "plugin-br-ted-lerian").useExistingSecret }}{{ (index .Values "plugin-br-ted-lerian").existingSecretName }}{{ else }}{{ include "plugin-br-ted-lerian.fullname" . }}{{ end }}
          - configMapRef:
              name: {{ include "plugin-br-ted-lerian.fullname" . }}
          env:
          - name: SHUTDOWN_DRAIN_DELAY
            value: "15s"
          {{- if $pgInternal }}
          {{- include "plugin-br-ted-lerian.infraSecretRef" (dict "context" . "subchart" "postgresql" "key" "password" "envName" "POSTGRES_PASSWORD") | nindent 10 }}
          {{- end }}
```

**Impact:**

- Kubernetes will wait up to 55 seconds for graceful shutdown before sending SIGKILL

**Migration:**

No action required. The new defaults are applied automatically on upgrade.

#### Customizing shutdown timeouts

If your application requires a longer or shorter grace period, you can override the default:

```yaml
plugin-br-ted-lerian:
  # Increase grace period for long-running requests
  terminationGracePeriodSeconds: 90
```

> **Warning:** Setting `terminationGracePeriodSeconds` too low may result in SIGKILL before graceful shutdown completes. Setting it too high may delay deployments and node drains unnecessarily.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.1 -n plugin-br-ted-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.1 -n plugin-br-ted-lerian
```
<!-- {% endraw %} -->
