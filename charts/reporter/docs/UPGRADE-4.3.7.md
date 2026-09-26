# Helm Upgrade from v4.3.6 to v4.3.7

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. RabbitMQ persistence configuration migrated to explicit PVC management](#1-rabbitmq-persistence-configuration-migrated-to-explicit-pvc-management)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
  - [Option 1: Keep existing RabbitMQ data (recommended)](#option-1-keep-existing-rabbitmq-data-recommended)
  - [Option 2: Fresh RabbitMQ installation](#option-2-fresh-rabbitmq-installation)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that changes how RabbitMQ persistence is managed. The chart now renders an explicit PersistentVolumeClaim with a `helm.sh/resource-policy: keep` annotation to prevent data loss during uninstall operations. The application version remains unchanged.

| Field | v4.3.6 | v4.3.7 |
|-------|--------|--------|
| Chart version | `4.3.6` | `4.3.7` |
| App version | `4.2.0` | `4.2.0` |

## Fixes

### 1. RabbitMQ persistence configuration migrated to explicit PVC management

The RabbitMQ subchart's persistence configuration has been replaced with an explicit PersistentVolumeClaim rendered by the parent chart. This change ensures that queued messages survive `helm uninstall` operations and prevents accidental data loss.

**What changed:**

- The `rabbitmq.persistence` block has been removed from `values.yaml`
- A new `rabbitmq.storage` block defines the PVC name, size, and optional storage class
- A new template file `templates/rabbitmq-pvc.yaml` renders the PVC with `helm.sh/resource-policy: keep`
- The RabbitMQ StatefulSet now references the pre-existing PVC instead of creating its own via `volumeClaimTemplates`

| Setting | v4.3.6 | v4.3.7 |
|---------|--------|--------|
| `rabbitmq.persistence.size` | `8Gi` | removed |
| `rabbitmq.storage.persistentVolumeClaimName` | not present | `reporter-rabbitmq` |
| `rabbitmq.storage.requestedSize` | not present | `8Gi` |
| `rabbitmq.storage.className` | not present | `""` (optional) |

**Before (v4.3.6):**

```yaml
rabbitmq:
  enabled: true
  persistence:
    size: 8Gi
```

**After (v4.3.7):**

```yaml
rabbitmq:
  enabled: true
  storage:
    persistentVolumeClaimName: reporter-rabbitmq
    requestedSize: 8Gi
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

> **Important:** The `helm.sh/resource-policy: keep` annotation ensures the PVC and its underlying PersistentVolume are retained when the chart is uninstalled. This prevents accidental loss of queued messages.

**Why this matters:**

In v4.3.6, the RabbitMQ StatefulSet created its own PVC via `volumeClaimTemplates`. When the chart was uninstalled, the PVC was deleted along with all queued messages. In v4.3.7, the chart renders the PVC explicitly and marks it for retention, ensuring data survives uninstall operations.

**Operational impact:**

- **New installations:** The chart will create a PVC named `reporter-rabbitmq` (or the value of `rabbitmq.storage.persistentVolumeClaimName`) before deploying the RabbitMQ StatefulSet.
- **Upgrades from v4.3.6:** If a PVC already exists from the previous StatefulSet, the upgrade will fail unless you migrate the existing PVC or create a new one. See [Migration Steps](#migration-steps) for detailed instructions.

## Configuration Changes

| Setting | v4.3.6 | v4.3.7 | Notes |
|---------|--------|--------|-------|
| `rabbitmq.persistence.size` | `8Gi` | removed | Replaced by `rabbitmq.storage.requestedSize` |
| `rabbitmq.storage.persistentVolumeClaimName` | not present | `reporter-rabbitmq` | Name of the PVC rendered by the chart |
| `rabbitmq.storage.requestedSize` | not present | `8Gi` | Size of the PVC |
| `rabbitmq.storage.className` | not present | `""` (optional) | Storage class for the PVC; omit to use cluster default |

**New configuration fields:**

| Field | Default | Description |
|-------|---------|-------------|
| `rabbitmq.storage.persistentVolumeClaimName` | `reporter-rabbitmq` | Name of the PVC that will be created and referenced by the RabbitMQ StatefulSet |
| `rabbitmq.storage.requestedSize` | `8Gi` | Size of the PVC (must match or exceed the size of any existing PVC being migrated) |
| `rabbitmq.storage.className` | `""` | Storage class name; if empty, the cluster's default storage class is used |

## Migration Steps

This upgrade requires manual intervention to handle the existing RabbitMQ PVC. Choose one of the following options based on your requirements.

### Option 1: Keep existing RabbitMQ data (recommended)

If you want to preserve queued messages and RabbitMQ state, you must rename the existing PVC to match the new chart-managed PVC name.

> **Warning:** This procedure requires downtime. RabbitMQ will be unavailable while the PVC is being renamed.

**Step 1: Identify the existing PVC**

```bash
kubectl get pvc -n reporter -l app.kubernetes.io/name=rabbitmq
```

The PVC name will typically be `data-reporter-rabbitmq-0` (where `reporter` is your release name).

**Step 2: Scale down the RabbitMQ StatefulSet**

```bash
kubectl scale statefulset reporter-rabbitmq --replicas=0 -n reporter
```

Wait for the RabbitMQ pod to terminate:

```bash
kubectl get pods -n reporter -l app.kubernetes.io/name=rabbitmq
```

**Step 3: Rename the existing PVC**

Kubernetes does not support renaming PVCs directly. You must create a new PVC with the desired name and copy the data from the old PVC.

**Option A: Use a temporary pod to copy data**

Create a temporary pod that mounts both the old and new PVCs:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: reporter-rabbitmq
  namespace: reporter
  annotations:
    helm.sh/resource-policy: keep
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: pvc-migrator
  namespace: reporter
spec:
  containers:
  - name: migrator
    image: busybox
    command: ["sh", "-c", "cp -a /old-data/. /new-data/ && echo 'Migration complete'"]
    volumeMounts:
    - name: old-data
      mountPath: /old-data
    - name: new-data
      mountPath: /new-data
  volumes:
  - name: old-data
    persistentVolumeClaim:
      claimName: data-reporter-rabbitmq-0
  - name: new-data
    persistentVolumeClaim:
      claimName: reporter-rabbitmq
  restartPolicy: Never
```

Apply the manifest:

```bash
kubectl apply -f pvc-migrator.yaml
```

Wait for the migration to complete:

```bash
kubectl logs -n reporter pvc-migrator -f
```

Delete the temporary pod:

```bash
kubectl delete pod pvc-migrator -n reporter
```

**Option B: Manually edit the PVC and PV**

If your storage backend supports it, you can manually rename the PVC by editing the PVC and PV resources. This approach is storage-specific and may not work with all provisioners.

**Step 4: Delete the old PVC**

```bash
kubectl delete pvc data-reporter-rabbitmq-0 -n reporter
```

**Step 5: Run the Helm upgrade**

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.7 -n reporter
```

The upgrade will detect the existing `reporter-rabbitmq` PVC and mount it to the RabbitMQ StatefulSet.

**Step 6: Verify RabbitMQ is running**

```bash
kubectl get pods -n reporter -l app.kubernetes.io/name=rabbitmq
```

Check RabbitMQ logs:

```bash
kubectl logs -n reporter reporter-rabbitmq-0 --tail=50
```

Verify that queued messages are intact:

```bash
kubectl exec -n reporter -it reporter-rabbitmq-0 -- rabbitmqctl list_queues
```

### Option 2: Fresh RabbitMQ installation

If you do not need to preserve existing RabbitMQ data, you can delete the old PVC and let the chart create a new one.

> **Warning:** This will delete all queued messages and RabbitMQ state. Only use this option if you can afford to lose in-flight messages.

**Step 1: Delete the RabbitMQ StatefulSet and PVC**

```bash
kubectl delete statefulset reporter-rabbitmq -n reporter
kubectl delete pvc data-reporter-rabbitmq-0 -n reporter
```

**Step 2: Run the Helm upgrade**

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.7 -n reporter
```

The chart will create a new PVC named `reporter-rabbitmq` and deploy a fresh RabbitMQ instance.

**Step 3: Verify RabbitMQ is running**

```bash
kubectl get pods -n reporter -l app.kubernetes.io/name=rabbitmq
```

Check RabbitMQ logs:

```bash
kubectl logs -n reporter reporter-rabbitmq-0 --tail=50
```

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.7 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.7 -n reporter
```
