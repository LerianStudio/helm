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

The `product-console-bootstrap-mongodb` Job template now includes annotations to enable native sidecar mode for Istio and Linkerd service meshes. This fixes an issue where the Job would never complete when a mesh proxy was injected as a regular container, because the sidecar proxy would continue running after the main container finished.

**What changed:**

The Job pod template now includes two annotations that instruct service mesh proxies to run in native sidecar mode, allowing the Job to complete successfully:

- `sidecar.istio.io/nativeSidecar: "true"` — enables Istio native sidecar mode
- `config.alpha.linkerd.io/proxy-enable-native-sidecar: "true"` — enables Linkerd native sidecar mode

**Why it matters:**

Without these annotations, if your cluster has automatic sidecar injection enabled (via namespace labels or other mechanisms), the bootstrap Job will hang indefinitely because the mesh proxy container never exits. The Job is a Helm `post-install,post-upgrade` hook (ArgoCD: `PostSync`), so a hung Job holds every `helm install`/`helm upgrade` until it times out.

The Job is rendered only when `global.externalMongoDefinitions.enabled=true` (default `false`): it creates or updates the console's user on an **external** MongoDB. With the bundled MongoDB subchart (the default) the Job does not exist and this change has no effect.

**Impact:**

- **If `global.externalMongoDefinitions.enabled` is `false` (default):** No impact. The Job is not rendered.
- **If you are not using a service mesh:** No impact. Nothing reads the annotations.
- **If you are using Istio or Linkerd with automatic injection:** The bootstrap Job will now complete successfully instead of hanging.
- **If you previously disabled sidecar injection for the bootstrap Job:** You can now remove those workarounds; the Job will work correctly with injection enabled.

> **Note:** Native sidecars need Kubernetes 1.28 or later (on 1.28 the `SidecarContainers` feature gate must be turned on; from 1.29 it is on by default) and a mesh version whose injector honours these annotations; check your mesh's documentation for the minimum version. Where either is missing, the annotations are ignored and you may need to keep excluding the bootstrap Job from sidecar injection on the mesh side.

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

When enabled, the bootstrap Job runs after every `helm install` and every `helm upgrade` (it is idempotent: create-or-update of the user), so the upgrade to v4.2.5 itself runs it with the new annotations. Helm deletes the previous Job before creating the new one (`hook-delete-policy: before-hook-creation,hook-succeeded`), and deletes it again once it succeeds.

## Migration Steps

This upgrade requires no configuration changes or operator action. The Helm upgrade will update the Job template with the new annotations.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command.
3. If `global.externalMongoDefinitions.enabled=true`, confirm the upgrade finished. A successful `helm upgrade` means the hook Job completed (it is deleted on success). A leftover Job from an earlier hung run is deleted by Helm before the new one is created, so no manual cleanup is needed. If the upgrade still waits on the Job, inspect it:

```bash
kubectl get jobs -n product-console -l app.kubernetes.io/name=product-console,app.kubernetes.io/component=bootstrap
kubectl logs -n product-console job/product-console-bootstrap-mongodb --all-containers
```

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.5 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.5 -n product-console
```
