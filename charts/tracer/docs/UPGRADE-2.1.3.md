# Helm Upgrade from v2.1.2 to v2.1.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Service mesh native sidecar support for bootstrap job](#1-service-mesh-native-sidecar-support-for-bootstrap-job)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `tracer` chart upgrade from `2.1.2` to `2.1.3`. This patch release fixes a critical issue with the PostgreSQL bootstrap job in service mesh environments. The application version remains unchanged at `1.0.0`.

| Field | v2.1.2 | v2.1.3 |
|-------|--------|--------|
| Chart version | `2.1.2` | `2.1.3` |
| App version | `1.0.0` | `1.0.0` |

## Fixes

### 1. Service mesh native sidecar support for bootstrap job

The `bootstrap-postgres` Job template now includes annotations to enable native sidecar mode for Istio and Linkerd service meshes. This fixes a long-standing issue where the bootstrap job would never complete in mesh-enabled namespaces because the injected proxy sidecar container would continue running after the main container finished.

**Before (v2.1.2):**

```yaml
spec:
  parallelism: 1
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      initContainers:
```

**After (v2.1.3):**

```yaml
spec:
  parallelism: 1
  backoffLimit: 3
  template:
    metadata:
      # A mesh proxy injected as a regular container never exits and the Job never completes.
      annotations:
        sidecar.istio.io/nativeSidecar: "true"
        config.alpha.linkerd.io/proxy-enable-native-sidecar: "true"
    spec:
      restartPolicy: Never
      initContainers:
```

**Operational impact:**

| Annotation | Service Mesh | Effect |
|------------|--------------|--------|
| `sidecar.istio.io/nativeSidecar: "true"` | Istio | Enables native sidecar mode (Kubernetes 1.29+), allowing the Job to complete when the main container exits |
| `config.alpha.linkerd.io/proxy-enable-native-sidecar: "true"` | Linkerd | Enables native sidecar mode (Kubernetes 1.29+), allowing the Job to complete when the main container exits |

**When this matters:**

- **Istio or Linkerd is installed** in your cluster with automatic sidecar injection enabled for the tracer namespace
- **Kubernetes 1.29 or later** is running (native sidecar support is required)
- The bootstrap job previously hung indefinitely with status `Running` and never transitioned to `Completed`

**When this does not matter:**

- No service mesh is installed
- Sidecar injection is disabled for the tracer namespace
- Kubernetes version is older than 1.29 (annotations are ignored)

> **Note:** If you are running Kubernetes 1.28 or earlier, these annotations will be ignored and the bootstrap job will continue to exhibit the hanging behavior in mesh environments. Consider upgrading to Kubernetes 1.29+ or disabling sidecar injection for the bootstrap job using mesh-specific annotations (e.g., `sidecar.istio.io/inject: "false"`).

> **Important:** Native sidecar mode requires Kubernetes 1.29+ and a compatible service mesh version. For Istio, native sidecar support is available in Istio 1.22+. For Linkerd, check your version's compatibility with native sidecars.

## Migration Steps

This upgrade is backward-compatible and requires no configuration changes. The new annotations are automatically applied to the bootstrap job.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. Verify your environment:

   ```bash
   kubectl version --short
   ```

   Confirm Kubernetes version is 1.29 or later for native sidecar support.

3. Apply the upgrade in a non-production environment first if you are running a service mesh.

4. After upgrading, verify the bootstrap job completes successfully:

   ```bash
   kubectl get jobs -n tracer -l app.kubernetes.io/name=tracer-helm,app.kubernetes.io/component=bootstrap
   ```

   The job should show `COMPLETIONS: 1/1` instead of remaining in `Running` state.

5. Check the job pod logs to confirm successful database initialization:

   ```bash
   kubectl logs -n tracer -l job-name=tracer-bootstrap-postgres --tail=50
   ```

6. Verify all tracer pods are running and healthy:

   ```bash
   kubectl get pods -n tracer
   ```

> **Note:** If you previously worked around the hanging bootstrap job by disabling sidecar injection (e.g., using `sidecar.istio.io/inject: "false"`), you can now remove that workaround and allow the native sidecar annotations to handle job completion correctly.

## Preview changes before upgrading

```bash
helm diff upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.3 -n tracer
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade tracer oci://registry-1.docker.io/lerianstudio/tracer-helm --version 2.1.3 -n tracer
```
