# Helm Upgrade from v8.0.0 to v8.0.1

# Topics

- **[Fixes](#fixes)**
  - [1. Auth Backend Resource Limits Now Applied](#1-auth-backend-resource-limits-now-applied)
  - [2. Adjusted Resource Defaults](#2-adjusted-resource-defaults)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Auth Backend Resource Limits Now Applied

In v8.0.0, the auth backend deployment template did not include a `resources` block, meaning that resource limits and requests defined in `values.yaml` were not being applied to the running pods. This has been fixed in v8.0.1.

**What changed:**

The auth backend deployment template now correctly references the resource configuration from values:

**Before (v8.0.0):**

```yaml
# templates/auth-backend/deployment.yaml
spec:
  containers:
    - name: auth-backend
      env:
        - name: "OTEL_EXPORTER_OTLP_ENDPOINT"
          value: "$(HOST_IP):4317"
      # No resources block - limits/requests were ignored
      readinessProbe:
        httpGet:
          path: {{ .Values.auth.backend.readinessProbe.path | default "/readyz" }}
```

**After (v8.0.1):**

```yaml
# templates/auth-backend/deployment.yaml
spec:
  containers:
    - name: auth-backend
      env:
        - name: "OTEL_EXPORTER_OTLP_ENDPOINT"
          value: "$(HOST_IP):4317"
      resources:
        {{- toYaml .Values.auth.backend.resources | nindent 12 }}
      readinessProbe:
        httpGet:
          path: {{ .Values.auth.backend.readinessProbe.path | default "/readyz" }}
```

**Why this matters:**

- **Resource limits are now enforced**: Pods will be constrained by the CPU and memory limits you specify
- **Resource requests are now honored**: Kubernetes scheduler will reserve the requested resources for your pods
- **Better cluster resource management**: Prevents auth backend pods from consuming unlimited resources
- **Improved stability**: Proper resource limits help prevent OOM kills and CPU throttling issues

> **Important:** If you were running v8.0.0 and expecting resource limits to be applied, they were silently ignored. After upgrading to v8.0.1, the limits will take effect immediately, which may cause pods to be rescheduled if nodes don't have sufficient capacity for the requested resources.

### 2. Adjusted Resource Defaults

The default resource limits and requests for the auth backend service have been updated to more balanced values.

| Setting | v8.0.0 | v8.0.1 |
|---------|--------|--------|
| `auth.backend.resources.limits.cpu` | `512m` | `1` (1000m) |
| `auth.backend.resources.limits.memory` | `2048Mi` | `1024Mi` |
| `auth.backend.resources.requests.cpu` | `256m` | `500m` |
| `auth.backend.resources.requests.memory` | `1024Mi` | `256Mi` |

**What this means for operators:**

The new defaults provide:
- **Higher CPU limit** (doubled from 512m to 1 core) to handle traffic spikes
- **Lower memory limit** (halved from 2Gi to 1Gi) based on actual usage patterns
- **Higher CPU request** (doubled from 256m to 500m) for better baseline performance
- **Lower memory request** (reduced from 1Gi to 256Mi) for more efficient cluster packing

**Default configuration in v8.0.1:**

```yaml
auth:
  backend:
    resources:
      # -- CPU and memory limits for pods
      limits:
        cpu: 1
        memory: 1024Mi
      # -- Minimum CPU and memory requests
      requests:
        cpu: 500m
        memory: 256Mi
```

> **Note:** These are default values. If you have explicitly set resource values in your `values.yaml` or via `--set` flags, your custom values will continue to be used and will not be affected by these default changes.

#### Option 1: Use New Defaults

If you want to adopt the new defaults, simply remove any custom resource configuration for auth backend from your values file:

```yaml
# Remove or comment out custom resource settings
auth:
  backend:
    # resources:
    #   limits:
    #     cpu: 512m
    #     memory: 2048Mi
```

#### Option 2: Keep Existing Values

If you prefer to maintain your current resource allocation, explicitly set them in your `values.yaml`:

```yaml
auth:
  backend:
    resources:
      limits:
        cpu: 512m
        memory: 2048Mi
      requests:
        cpu: 256m
        memory: 1024Mi
```

#### Option 3: Customize for Your Environment

Adjust resources based on your observed usage patterns:

```yaml
auth:
  backend:
    resources:
      limits:
        cpu: 2
        memory: 2048Mi
      requests:
        cpu: 1
        memory: 512Mi
```

> **Warning:** If your cluster nodes have limited resources, the increased CPU request (500m vs 256m) may affect pod scheduling. Ensure your nodes have sufficient allocatable CPU before upgrading, or override the request value to match your cluster capacity.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.0.1 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 8.0.1 -n plugin-access-manager
```
