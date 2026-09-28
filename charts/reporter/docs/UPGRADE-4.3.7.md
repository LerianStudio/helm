# Helm Upgrade from v4.3.6 to v4.3.7

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. The bundled RabbitMQ broker now keeps its data on a PersistentVolumeClaim](#1-the-bundled-rabbitmq-broker-now-keeps-its-data-on-a-persistentvolumeclaim)
- **[Configuration Changes](#configuration-changes)**
- **[Who is affected](#who-is-affected)**
- **[Migration Steps](#migration-steps)**
  - [Default installations (no `rabbitmq.storage` override)](#default-installations-no-rabbitmqstorage-override)
  - [Installations that set `rabbitmq.storage.requestedSize`](#installations-that-set-rabbitmqstoragerequestedsize)
  - [Installations using an external broker](#installations-using-an-external-broker)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that gives the bundled RabbitMQ broker (`rabbitmq.enabled: true`, the chart default) a persistent data directory. Until v4.3.6 the broker's data directory was an `emptyDir`, so queued messages were lost on every broker pod restart. The chart now renders a PersistentVolumeClaim with `helm.sh/resource-policy: keep` and points the broker StatefulSet at it. The application version is unchanged.

| Field | v4.3.6 | v4.3.7 |
|-------|--------|--------|
| Chart version | `4.3.6` | `4.3.7` |
| App version | `4.2.0` | `4.2.0` |

## Fixes

### 1. The bundled RabbitMQ broker now keeps its data on a PersistentVolumeClaim

**What changed:**

- The `rabbitmq.persistence` block was removed from `values.yaml`. It was never read by the bundled RabbitMQ subchart, which configures storage through `rabbitmq.storage`, so in v4.3.6 the broker ran on an `emptyDir`.
- A new `rabbitmq.storage` block sets `persistentVolumeClaimName: reporter-rabbitmq` and `requestedSize: 8Gi`.
- A new template, `templates/rabbitmq-pvc.yaml`, renders that PVC with `helm.sh/resource-policy: keep`.
- The broker StatefulSet mounts the PVC as a regular pod volume (`persistentVolumeClaim.claimName: reporter-rabbitmq`). It does **not** use `volumeClaimTemplates`, so a default upgrade only changes the pod template, which Kubernetes allows on an existing StatefulSet.

**Before (v4.3.6):**

```yaml
# values.yaml
rabbitmq:
  enabled: true
  persistence:
    size: 8Gi   # not read by the subchart
```

```yaml
# Rendered StatefulSet reporter-rabbitmq (volumes)
- name: rabbitmq-volume
  emptyDir: {}
```

**After (v4.3.7):**

```yaml
# values.yaml
rabbitmq:
  enabled: true
  storage:
    persistentVolumeClaimName: reporter-rabbitmq
    requestedSize: 8Gi
```

```yaml
# Rendered StatefulSet reporter-rabbitmq (volumes)
- name: rabbitmq-volume
  persistentVolumeClaim:
    claimName: reporter-rabbitmq
```

**Rendered PVC (v4.3.7):**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: reporter-rabbitmq
  labels:
    app.kubernetes.io/name: rabbitmq
    app.kubernetes.io/instance: reporter
    app.kubernetes.io/managed-by: Helm
  annotations:
    helm.sh/resource-policy: keep
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
```

**Operational impact:**

- **One-time loss of in-flight messages.** The upgrade replaces the broker pod. Messages queued in the old `emptyDir` are lost at that moment, and the new pod starts on an empty volume. From then on, queued messages survive pod restarts, upgrades and `helm uninstall`. Drain the queues or run the upgrade when no reports are pending.
- **A StorageClass is now required.** The PVC sets no `storageClassName` unless you set `rabbitmq.storage.className`, so it binds through the cluster's default StorageClass. With no default StorageClass the PVC stays `Pending` and the broker pod does not start.
- **The PVC name is fixed.** The default name is `reporter-rabbitmq` whatever the release name is. Because the PVC is kept on uninstall, installing a release with a **different name** in the same namespace fails with `invalid ownership metadata` until the kept PVC is deleted or `rabbitmq.storage.persistentVolumeClaimName` is changed. Reinstalling with the **same** release name reuses the PVC.
- **One broker replica only.** The claim is `ReadWriteOnce` and shared by every broker pod, so keep `rabbitmq.replicaCount` at `1` (the default).
- To delete the broker data for good, remove the PVC after uninstalling:

```bash
kubectl delete pvc reporter-rabbitmq -n <namespace>
```

## Configuration Changes

| Setting | v4.3.6 | v4.3.7 | Notes |
|---------|--------|--------|-------|
| `rabbitmq.persistence.size` | `8Gi` | removed | Was never read by the subchart |
| `rabbitmq.storage.persistentVolumeClaimName` | not set | `reporter-rabbitmq` | The PVC the chart renders and the broker mounts |
| `rabbitmq.storage.requestedSize` | not set | `8Gi` | Size of that PVC |
| `rabbitmq.storage.className` | not set | not set (optional) | StorageClass for the PVC; unset uses the cluster default |

## Who is affected

| Installation | Result of `helm upgrade` |
|--------------|--------------------------|
| Bundled broker, no `rabbitmq.storage` override (default) | Succeeds. Broker pod restarts on a new, empty PVC (one-time loss of in-flight messages). |
| Bundled broker with `rabbitmq.storage.requestedSize` set in your values | **Fails** — see below. |
| External broker (`rabbitmq.enabled: false`) | Not affected. The PVC is not rendered. |

## Migration Steps

### Default installations (no `rabbitmq.storage` override)

No values change is required.

1. Make sure the cluster has a default StorageClass, or set `rabbitmq.storage.className`:

   ```bash
   kubectl get storageclass
   ```

2. Drain or wait for pending report jobs (queued messages in the old `emptyDir` are lost when the broker pod is replaced).
3. Run the upgrade (see [Command to upgrade](#command-to-upgrade)).
4. Verify the PVC is bound and the broker is running:

   ```bash
   kubectl get pvc reporter-rabbitmq -n <namespace>
   kubectl get pods -n <namespace> -l app.kubernetes.io/name=rabbitmq
   ```

> **Warning:** Do not create the `reporter-rabbitmq` PVC by hand before upgrading. A PVC that Helm did not create has no Helm ownership metadata, and the upgrade fails with `invalid ownership metadata`.

### Installations that set `rabbitmq.storage.requestedSize`

If your values already set `rabbitmq.storage.requestedSize` (the subchart's own way to get a persistent volume), v4.3.6 rendered the broker StatefulSet with `volumeClaimTemplates`, and the PVC is named `rabbitmq-volume-<release>-rabbitmq-0`. In v4.3.7 the new default `persistentVolumeClaimName` is merged into your values, which removes `volumeClaimTemplates` from the StatefulSet. Kubernetes refuses that change and the upgrade fails:

```text
Error: UPGRADE FAILED: cannot patch "<release>-rabbitmq" with kind StatefulSet: StatefulSet.apps "<release>-rabbitmq" is invalid: spec: Forbidden: updates to statefulset spec for fields other than 'replicas', 'ordinals', 'template', 'updateStrategy', 'persistentVolumeClaimRetentionPolicy' and 'minReadySeconds' are forbidden
```

The release is then marked `failed`, and resources applied before the StatefulSet (for example the `reporter-manager` and `reporter-worker` Secrets, which are pre-upgrade hooks) are already updated.

To keep your existing volume and its data, unset the new claim name so the subchart keeps its `volumeClaimTemplates`:

```yaml
rabbitmq:
  storage:
    persistentVolumeClaimName: null
    requestedSize: 8Gi   # your existing size
```

or on the command line, alongside your usual values files:

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.7 -n <namespace> \
  -f <your-values.yaml> --set rabbitmq.storage.persistentVolumeClaimName=null
```

With `persistentVolumeClaimName: null`, `templates/rabbitmq-pvc.yaml` renders nothing and the StatefulSet spec is unchanged.

### Installations using an external broker

No action required.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.7 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.7 -n reporter
```
