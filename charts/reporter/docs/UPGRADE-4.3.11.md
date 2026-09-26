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

Three Job resources now include annotations that enable native sidecar support for Istio and Linkerd service meshes. Without these annotations, mesh proxies injected as regular containers never exit, preventing Jobs from completing successfully.

**Affected resources:**

- `bootstrap-mongodb` Job
- `bootstrap-rabbitmq` Job
- `worker` KEDA ScaledJob (when `worker.keda.enabled=true`)

**Added annotations:**

| Annotation | Value | Purpose |
|------------|-------|---------|
| `sidecar.istio.io/nativeSidecar` | `"true"` | Enables Istio native sidecar mode (Istio 1.22+) |
| `config.alpha.linkerd.io/proxy-enable-native-sidecar` | `"true"` | Enables Linkerd native sidecar mode (Linkerd 2.14+) |

**Before (v4.3.10):**

```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: bootstrap
```

**After (v4.3.11):**

```yaml
spec:
  template:
    metadata:
      annotations:
        sidecar.istio.io/nativeSidecar: "true"
        config.alpha.linkerd.io/proxy-enable-native-sidecar: "true"
    spec:
      restartPolicy: Never
      containers:
        - name: bootstrap
```

> **Note:** These annotations are harmless when no service mesh is installed. If you are running Istio < 1.22 or Linkerd < 2.14, native sidecar mode is not supported and Jobs may still hang. In that case, disable sidecar injection for Job pods using namespace or pod-level annotations (e.g., `sidecar.istio.io/inject: "false"`).

**Operational impact:**

- **Istio users:** Jobs will now complete successfully when using Istio 1.22+ with native sidecar support enabled. The sidecar container will terminate after the Job container exits.
- **Linkerd users:** Jobs will now complete successfully when using Linkerd 2.14+ with native sidecar support enabled. The proxy container will terminate after the Job container exits.
- **No mesh installed:** No impact. The annotations are ignored.
- **Older mesh versions:** If you are running an older version of Istio or Linkerd that does not support native sidecars, you must disable sidecar injection for Job pods to prevent them from hanging. Add the following to your values:

```yaml
bootstrap:
  podAnnotations:
    sidecar.istio.io/inject: "false"
    linkerd.io/inject: disabled

worker:
  keda:
    scaledJob:
      podAnnotations:
        sidecar.istio.io/inject: "false"
        linkerd.io/inject: disabled
```

> **Important:** The chart does not currently expose `bootstrap.podAnnotations` or `worker.keda.scaledJob.podAnnotations` fields in `values.yaml`. If you need to disable sidecar injection for older mesh versions, you may need to patch the Job resources after upgrade or request this feature from the chart maintainers.

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
- **Upgrade behavior:** On upgrade to v4.3.11, the annotation will be added but the ConfigMap content is unchanged, so no restart will occur unless you also modify ConfigMap values.

> **Note:** This change ensures that configuration updates are applied without requiring manual pod restarts. The checksum is computed at template render time, so any change to the ConfigMap template (including changes to values that populate the ConfigMap) will result in a new checksum and trigger a restart.

## Migration Steps

This upgrade requires no mandatory values changes or operator action. The changes are template-only and will take effect automatically on upgrade.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. If you are running a service mesh, verify your mesh version supports native sidecars:
   - **Istio:** Version 1.22 or later
   - **Linkerd:** Version 2.14 or later
   
   If you are running an older version, see the note in [Fix #1](#1-service-mesh-sidecar-compatibility-for-jobs) for workaround instructions.

3. Run the upgrade command during a maintenance window.
4. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n <namespace>
```

5. Verify that bootstrap Jobs completed successfully:

```bash
kubectl get jobs -n <namespace> -l app.kubernetes.io/name=reporter
```

6. If using KEDA ScaledJobs, verify that worker Jobs complete successfully:

```bash
kubectl get jobs -n <namespace> -l app.kubernetes.io/component=worker
```

> **Note:** The upgrade will trigger a rolling restart of the manager and worker Deployments due to the new `checksum/config` annotation. No downtime is expected for the manager (assuming multiple replicas or a readiness probe grace period). Worker restarts will temporarily pause job processing.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.11 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.11 -n <namespace>
```
