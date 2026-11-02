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

The chart now configures two complementary shutdown timeouts:

1. **Pod termination grace period** (`terminationGracePeriodSeconds: 55`): Kubernetes waits 55 seconds after sending SIGTERM before forcefully killing the pod
2. **Application drain delay** (`SHUTDOWN_DRAIN_DELAY: 15s`): The application waits 15 seconds before beginning shutdown to allow load balancers and service meshes to remove the pod from rotation

**Why it matters:**

Without explicit shutdown configuration, pods may be terminated while still processing requests, leading to:
- Failed requests during deployments or node drains
- Incomplete database transactions
- Lost in-flight work

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
- `SHUTDOWN_DRAIN_DELAY`: Duration to wait before beginning shutdown (default: `15s`)

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

- Pods will now wait 15 seconds after receiving SIGTERM before beginning shutdown
- Kubernetes will wait up to 55 seconds for graceful shutdown before sending SIGKILL
- Deployments and node drains will take slightly longer but will be safer

**Migration:**

No action required. The new defaults are applied automatically on upgrade.

#### Customizing shutdown timeouts

If your application requires different shutdown timing (e.g., longer request processing time), you can override the defaults:

```yaml
plugin-br-ted-lerian:
  # Increase grace period for long-running requests
  terminationGracePeriodSeconds: 90
  
  # Increase drain delay if load balancer deregistration is slow
  extraEnvVars:
    - name: SHUTDOWN_DRAIN_DELAY
      value: "30s"
```

> **Note:** Ensure `terminationGracePeriodSeconds` is always greater than `SHUTDOWN_DRAIN_DELAY` plus your expected maximum request duration. A good formula is: `terminationGracePeriodSeconds = SHUTDOWN_DRAIN_DELAY + max_request_duration + 10s margin`

> **Warning:** Setting `terminationGracePeriodSeconds` too low may result in SIGKILL before graceful shutdown completes. Setting it too high may delay deployments and node drains unnecessarily.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.1 -n plugin-br-ted-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.1 -n plugin-br-ted-lerian
```
<!-- {% endraw %} -->
