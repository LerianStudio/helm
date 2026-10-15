# Helm Upgrade from v9.5.4 to v9.5.5

# Topics

- **[Fixes](#fixes)**
  - [1. Automatic Pod Restart on Secret Changes](#1-automatic-pod-restart-on-secret-changes)
  - [2. Service Mesh Compatibility for Init User Job](#2-service-mesh-compatibility-for-init-user-job)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Automatic Pod Restart on Secret Changes

This release adds checksum annotations to deployment pod templates to automatically trigger pod restarts when secrets change.

**What changed:**

The auth, identity, and caradhras deployments now include checksum annotations that calculate a hash of their dependent secrets. When you update a secret and run `helm upgrade`, Kubernetes will automatically roll out new pods with the updated configuration.

| Service | Secrets Tracked |
|---------|----------------|
| Auth | `auth/secrets.yaml` |
| Identity | `identity/secrets.yaml` |
| Caradhras | `caradhras/secrets.yaml`, `auth/secrets.yaml`, `auth-database/secrets.yaml` |

**Before (v9.5.4):**

```yaml
# auth deployment
spec:
  template:
    metadata:
      labels:
        {{- include "plugin-auth.labels" (dict "context" . "name" .Values.auth.name ) | nindent 8 }}
    spec:
      # ... containers
```

**After (v9.5.5):**

```yaml
# auth deployment
spec:
  template:
    metadata:
      annotations:
        checksum/secret: {{ include (print $.Template.BasePath "/auth/secrets.yaml") . | sha256sum }}
      labels:
        {{- include "plugin-auth.labels" (dict "context" . "name" .Values.auth.name ) | nindent 8 }}
    spec:
      # ... containers
```

**Why this matters:**

Previously, when you updated secrets in your `values.yaml` and ran `helm upgrade`, the pods would not restart automatically. You had to manually delete pods or perform a rollout restart to pick up the new secret values. This could lead to:

- Pods running with stale credentials
- Manual intervention required after every secret rotation
- Potential downtime if operators forgot to restart pods

With v9.5.5, the checksum annotation ensures that any secret change triggers an automatic rolling update of the affected pods.

**What this means for operators:**

- **No action required** — this is an automatic improvement
- Secret updates via `helm upgrade` will now trigger pod restarts automatically
- The rolling update respects your deployment strategy (maxUnavailable, maxSurge)
- You no longer need to manually restart pods after rotating credentials

> **Note:** The checksum is calculated at template rendering time. If you update secrets directly in Kubernetes (via `kubectl edit secret`) without running `helm upgrade`, pods will not restart. Always update secrets through Helm values or external secret operators that trigger Helm releases.

**Example: Secret rotation workflow**

```bash
# Update your values.yaml with new credentials
# auth:
#   secrets:
#     LICENSE_KEY: new-license-key-value

# Run helm upgrade - pods will restart automatically
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 9.5.5 \
  -n plugin-access-manager \
  -f values.yaml
```

### 2. Service Mesh Compatibility for Init User Job

The auth init user job now includes annotations for Istio and Linkerd service mesh compatibility using native sidecars.

**What changed:**

Two new annotations have been added to the init user job pod template:

```yaml
annotations:
  sidecar.istio.io/nativeSidecar: "true"
  config.alpha.linkerd.io/proxy-enable-native-sidecar: "true"
```

**Before (v9.5.4):**

```yaml
# auth/init_user.yaml
spec:
  template:
    metadata:
      labels:
        {{- include "plugin-auth.selectorLabels" (dict "context" . "name" .Values.auth.name) | nindent 8 }}
        app.kubernetes.io/component: init-user
    spec:
      # ... job spec
```

**After (v9.5.5):**

```yaml
# auth/init_user.yaml
spec:
  template:
    metadata:
      labels:
        {{- include "plugin-auth.selectorLabels" (dict "context" . "name" .Values.auth.name) | nindent 8 }}
        app.kubernetes.io/component: init-user
      # A mesh proxy injected as a regular container never exits and the Job never completes.
      annotations:
        sidecar.istio.io/nativeSidecar: "true"
        config.alpha.linkerd.io/proxy-enable-native-sidecar: "true"
    spec:
      # ... job spec
```

**Why this matters:**

Kubernetes Jobs must complete successfully for the deployment to proceed. When a service mesh injects a sidecar proxy as a regular container (not an init container), the proxy continues running even after the job's main container finishes. This prevents the job from ever reaching a "Completed" state, blocking your deployment.

The native sidecar feature (available in Kubernetes 1.28+) allows the mesh proxy to run as a true sidecar that terminates when the main container completes.

**What this means for operators:**

- **If you use Istio or Linkerd:** The init user job will now complete successfully with sidecar injection enabled
- **If you don't use a service mesh:** These annotations have no effect and are safely ignored
- **If you use Kubernetes < 1.28:** Native sidecars are not supported; you may need to disable sidecar injection for this job using your mesh's exclusion annotations

> **Important:** This fix requires Kubernetes 1.28 or later for native sidecar support. If you're running an older Kubernetes version and experiencing job completion issues, you should disable sidecar injection for the init user job using your service mesh's annotation (e.g., `sidecar.istio.io/inject: "false"`).

**Example: Disabling sidecar injection on older Kubernetes versions**

If you're running Kubernetes < 1.28 and the init user job doesn't complete, you can disable sidecar injection by adding custom annotations in your `values.yaml`:

```yaml
auth:
  initUser:
    podAnnotations:
      sidecar.istio.io/inject: "false"
      linkerd.io/inject: disabled
```

> **Note:** The chart does not currently expose a `podAnnotations` field for the init user job. If you need to disable sidecar injection, you may need to fork the chart or request this feature from the maintainers.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.5 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.5 -n plugin-access-manager
```
