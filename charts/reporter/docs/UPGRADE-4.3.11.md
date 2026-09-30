# Helm Upgrade from v4.3.10 to v4.3.11

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Service mesh sidecar compatibility for Jobs](#1-service-mesh-sidecar-compatibility-for-jobs)
  - [2. ConfigMap change detection for manager and worker](#2-configmap-change-detection-for-manager-and-worker)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that fixes service mesh sidecar compatibility for Job resources and adds ConfigMap change detection to manager and worker Deployments. The application version remains unchanged.

| Field | v4.3.10 | v4.3.11 |
|-------|---------|---------|
| Chart version | `4.3.10` | `4.3.11` |
| App version | `4.2.0` | `4.2.0` |

## Fixes

### 1. Service mesh sidecar compatibility for Jobs

Three Job pod templates now carry annotations that ask Istio and Linkerd to inject their proxy as a Kubernetes native sidecar (an init container with `restartPolicy: Always`). A proxy injected as a regular container never exits, so the Job never reaches `Complete`; a native sidecar is stopped by Kubernetes once the Job's containers finish.

**Affected resources:**

- `reporter-bootstrap-mongodb` Job — rendered only when `global.externalMongoDefinitions.enabled=true` (hook: `post-install,pre-upgrade`)
- `reporter-bootstrap-rabbitmq` Job — rendered only when `externalRabbitmqDefinitions.enabled=true` (hook: `pre-install,pre-upgrade`)
- `reporter-worker` KEDA ScaledJob — rendered when KEDA is enabled (`keda.enabled` or `keda.external`) and `worker.keda.scaledJob.enabled=true`

**Added annotations:**

| Annotation | Value | Read by |
|------------|-------|---------|
| `sidecar.istio.io/nativeSidecar` | `"true"` | Istio sidecar injector |
| `config.alpha.linkerd.io/proxy-enable-native-sidecar` | `"true"` | Linkerd proxy injector |

**Before (v4.3.10):**

```yaml
spec:
  template:
    spec:
      restartPolicy: Never
```

**After (v4.3.11):**

```yaml
spec:
  template:
    metadata:
      # A mesh proxy injected as a regular container never exits and the Job never completes.
      annotations:
        sidecar.istio.io/nativeSidecar: "true"
        config.alpha.linkerd.io/proxy-enable-native-sidecar: "true"
    spec:
      restartPolicy: Never
```

> **Note:** Native sidecars need Kubernetes 1.28 or later: on 1.28 the `SidecarContainers` feature gate must be turned on, from 1.29 it is on by default, and a mesh version whose injector honours the annotation above. Check your mesh's documentation for the minimum version. Where either is missing, the annotations are ignored and a Job with an injected proxy can still hang, exactly as in v4.3.10.

**Operational impact:**

- **No mesh installed:** No impact. Nothing reads these annotations.
- **Istio or Linkerd with injection enabled, native sidecars supported:** The Jobs now complete instead of hanging with a running proxy.
- **Mesh or Kubernetes without native sidecar support:** Behaviour is unchanged. The chart does not expose a values key to add pod annotations to these Jobs, so to avoid a hanging Job either exclude the namespace or these pods from injection on the mesh side, or keep the Jobs disabled (both bootstrap Jobs are off by default).

### 2. ConfigMap change detection for manager and worker

The `manager` and `worker` Deployments now include a `checksum/config` annotation that triggers a rolling restart when their respective ConfigMaps change. Previously, only Secret changes triggered restarts via the `checksum/secret` annotation.

**Added annotations:**

| Deployment | Annotation | Template path |
|------------|------------|---------------|
| `manager` | `checksum/config` | `/manager/configmap.yaml` |
| `worker` | `checksum/config` | `/worker/configmap.yaml` |

**Before (v4.3.10):**

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/secret: {{ include (print $.Template.BasePath "/manager/secrets.yaml") . | sha256sum }}
```

**After (v4.3.11):**

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/secret: {{ include (print $.Template.BasePath "/manager/secrets.yaml") . | sha256sum }}
        checksum/config: {{ include (print $.Template.BasePath "/manager/configmap.yaml") . | sha256sum }}
```

**Operational impact:**

- **Manager:** Changes to `manager.configmap` values will now trigger a rolling restart of the manager Deployment automatically.
- **Worker:** Changes to `worker.configmap` values will now trigger a rolling restart of the worker Deployment automatically.
- **Upgrade behavior:** Adding the `checksum/config` annotation changes the pod template, so the upgrade to v4.3.11 itself rolls the manager Deployment and the worker Deployment once, even if no ConfigMap value changed.
- **Worker scope:** The worker Deployment exists only when KEDA is disabled (`keda.enabled=false` and `keda.external=false`). With the default KEDA ScaledJob, each worker Job is a new pod that already reads the current ConfigMap, so no annotation is needed there.

> **Note:** This change ensures that configuration updates are applied without requiring manual pod restarts. The checksum is computed at template render time, so any change to the ConfigMap template (including changes to values that populate the ConfigMap) will result in a new checksum and trigger a restart.

## Migration Steps

This upgrade requires no mandatory values changes or operator action. The changes are template-only and will take effect automatically on upgrade.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. If Istio or Linkerd injects into this namespace, confirm your cluster runs Kubernetes 1.29 or later (or 1.28 with the `SidecarContainers` feature gate) and that your mesh version supports native sidecars (see the note in [Fix #1](#1-service-mesh-sidecar-compatibility-for-jobs)).
3. Run the upgrade command. The manager Deployment (and the worker Deployment, when KEDA is disabled) restarts once.
4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

5. If the bootstrap Jobs are enabled, confirm the upgrade finished: both are Helm hooks deleted on success (`hook-delete-policy: before-hook-creation,hook-succeeded`), so a successful `helm upgrade` means they completed. A Job still listed as running points at a proxy that did not exit:

```bash
kubectl get jobs -n <namespace> reporter-bootstrap-mongodb reporter-bootstrap-rabbitmq
```

6. If using the KEDA ScaledJob, verify that worker Jobs reach `Complete`:

```bash
kubectl get jobs -n <namespace>
```

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.11 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.11 -n <namespace>
```
