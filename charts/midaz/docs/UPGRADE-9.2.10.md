# Helm Upgrade from v9.2.9 to v9.2.10

## Topics

- **[Fixes](#fixes)**
  - [1. RabbitMQ persistence setting removed (no rendered change)](#1-rabbitmq-persistence-setting-removed-no-rendered-change)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. RabbitMQ persistence setting removed (no rendered change)

The chart's default values no longer set `rabbitmq.persistence.size`. The bundled RabbitMQ subchart (`groundhog2k/rabbitmq` 2.1.11) never read a `persistence` key: its storage is configured under `rabbitmq.storage.*`, and with `storage.requestedSize` and `storage.persistentVolumeClaimName` both empty it mounts an `emptyDir`. The removed value only suggested a volume that was never created.

#### What changed

| Setting | v9.2.9 | v9.2.10 |
|---------|--------|---------|
| `rabbitmq.persistence.size` | `8Gi` (ignored by the subchart) | *removed* |
| Bundled broker data volume | `emptyDir` | `emptyDir` (unchanged) |

**Before (v9.2.9):**

```yaml
rabbitmq:
  persistence:
    size: 8Gi
```

**After (v9.2.10):**

```yaml
rabbitmq:
  # -- No persistent volume (emptyDir): queues and messages are lost when the broker pod is recreated. Kubernetes
  # refuses changes to a StatefulSet's volumeClaimTemplates, so adding `storage.requestedSize` later needs it deleted first.
```

#### Operational impact

- **No rendered change:** the RabbitMQ StatefulSet and every other manifest render the same as in v9.2.9. The upgrade does not restart the broker, and no PVC is created, kept or removed.
- **Existing behavior, now documented:** the bundled broker has always stored its data in an `emptyDir`. Queues and messages are lost whenever the broker pod is recreated (node drain, eviction, rescheduling), in this and in earlier versions.

#### Action required

No action is required for the upgrade itself.

If you need durable messages from the bundled broker, configure storage explicitly. Either reference a PVC you create yourself; this changes only the pod's volumes and is applied by a normal upgrade (the broker pod restarts):

```yaml
rabbitmq:
  storage:
    persistentVolumeClaimName: "my-rabbitmq-data"
```

Or let the subchart create a PVC per replica. This adds `volumeClaimTemplates`, which Kubernetes refuses to change on an existing StatefulSet, so delete the StatefulSet (keeping its pod) before upgrading:

```yaml
rabbitmq:
  storage:
    requestedSize: 8Gi
    className: ""  # empty uses the default StorageClass
```

```bash
kubectl delete statefulset <release>-rabbitmq -n midaz --cascade=orphan
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.10 -n midaz -f values.yaml
```

> **Warning:** Either way the broker pod is recreated on the new volume, starting empty: messages queued in the `emptyDir` are lost. Drain the queues first.

For production, an external broker (`rabbitmq.enabled: false` with the ledger's `RABBITMQ_*` settings pointing at it) avoids running a single-pod broker inside the release.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.10 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.10 -n midaz
```
