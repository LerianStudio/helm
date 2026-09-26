# Helm Upgrade from v4.2.4 to v4.2.5

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Service mesh native sidecar support for MongoDB bootstrap Job](#1-service-mesh-native-sidecar-support-for-mongodb-bootstrap-job)
- **[Template Changes](#template-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that adds service mesh compatibility annotations to the MongoDB bootstrap Job. The application version is unchanged.

| Field | v4.2.4 | v4.2.5 |
|-------|--------|--------|
| Chart version | `4.2.4` | `4.2.5` |
| App version | `2.2.1` | `2.2.1` |

## Fixes

### 1. Service mesh native sidecar support for MongoDB bootstrap Job

The `bootstrap-mongodb` Job template now includes annotations to enable native sidecar mode for Istio and Linkerd service meshes. This fixes an issue where the Job would never complete when a mesh proxy was injected as a regular container, because the sidecar proxy would continue running after the main container finished.

**What changed:**

The Job pod template now includes two annotations that instruct service mesh proxies to run in native sidecar mode, allowing the Job to complete successfully:

- `sidecar.istio.io/nativeSidecar: "true"` — enables Istio native sidecar mode
- `config.alpha.linkerd.io/proxy-enable-native-sidecar: "true"` — enables Linkerd native sidecar mode

**Why it matters:**

Without these annotations, if your cluster has automatic sidecar injection enabled (via namespace labels or other mechanisms), the bootstrap Job will hang indefinitely because the mesh proxy container never exits. This prevents the Job from completing and blocks the initial MongoDB setup.

**Impact:**

- **If you are not using a service mesh:** No impact. The annotations are ignored by Kubernetes.
- **If you are using Istio or Linkerd with automatic injection:** The bootstrap Job will now complete successfully instead of hanging.
- **If you previously disabled sidecar injection for the bootstrap Job:** You can now remove those workarounds; the Job will work correctly with injection enabled.

> **Note:** Native sidecar support requires Kubernetes 1.28+ and Istio 1.22+ or Linkerd 2.14+. If you are running older versions, the annotations will be ignored and you may need to continue using sidecar injection exclusions for the bootstrap Job.

## Template Changes

**Before (v4.2.4):**

```yaml
spec:
  parallelism: 1
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      initContainers:
```

**After (v4.2.5):**

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

The next time the bootstrap Job runs (typically only during initial installation or when manually triggered), it will include the native sidecar annotations. Existing completed Jobs are not affected.

## Migration Steps

This upgrade requires no configuration changes or operator action. The Helm upgrade will update the Job template with the new annotations.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command.
3. If the bootstrap Job is currently running and stuck, delete it after the upgrade to allow Helm to recreate it with the new annotations:

```bash
kubectl delete job -n product-console -l app.kubernetes.io/name=product-console,app.kubernetes.io/component=bootstrap-mongodb
```

4. Verify the Job completes successfully if it runs:

```bash
kubectl get jobs -n product-console -l app.kubernetes.io/component=bootstrap-mongodb
kubectl logs -n product-console -l job-name=<job-name> --all-containers
```

> **Important:** The bootstrap Job typically runs only during initial chart installation when MongoDB initialization is required. If you are upgrading an existing installation where MongoDB is already configured, the Job may not run at all.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.5 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.5 -n product-console
```
