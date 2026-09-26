# Helm Upgrade from v9.2.9 to v9.2.10

## Topics

- **[Fixes](#fixes)**
  - [1. RabbitMQ persistence configuration update](#1-rabbitmq-persistence-configuration-update)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. RabbitMQ persistence configuration update

The RabbitMQ persistence configuration has been updated to remove the default persistent volume size specification. This change addresses a Kubernetes limitation where StatefulSet `volumeClaimTemplates` cannot be modified after creation.

#### What changed

| Setting | v9.2.9 | v9.2.10 |
|---------|--------|---------|
| `rabbitmq.persistence.size` | `8Gi` | *removed* |

**Before (v9.2.9):**

```yaml
rabbitmq:
  enabled: true
  image:
    tag: "3.13.6"
  persistence:
    size: 8Gi
  resources:
    requests:
      cpu: 250m
```

**After (v9.2.10):**

```yaml
rabbitmq:
  enabled: true
  image:
    tag: "3.13.6"
  # -- No persistent volume (emptyDir): queues and messages are lost when the broker pod is recreated. Kubernetes
  # refuses changes to a StatefulSet's volumeClaimTemplates, so adding `storage.requestedSize` later needs it deleted first.
  resources:
    requests:
      cpu: 250m
```

#### Why this matters

By default, RabbitMQ now uses an `emptyDir` volume instead of a PersistentVolumeClaim. This means:

- **Queues and messages are ephemeral** — they will be lost when the RabbitMQ pod is recreated (e.g., during upgrades, node failures, or pod evictions)
- **No PVC conflicts** — operators can add persistent storage later by setting `rabbitmq.storage.requestedSize` without encountering Kubernetes StatefulSet immutability errors
- **Simpler initial deployment** — no need to provision PersistentVolumes for development or testing environments

> **Warning:** This configuration is **not suitable for production** environments where message durability is required. For production deployments, you must explicitly configure persistent storage.

#### Migration options

##### Option 1: Continue with ephemeral storage (development/testing)

If you are running a development or testing environment where message loss is acceptable, no action is required. The upgrade will proceed with ephemeral storage.

> **Important:** After upgrade, the RabbitMQ pod will restart with an empty queue. Any messages in flight will be lost.

##### Option 2: Add persistent storage (production)

If you need persistent storage for RabbitMQ, configure it explicitly in your `values.yaml`:

```yaml
rabbitmq:
  enabled: true
  storage:
    requestedSize: 8Gi
    className: ""  # Use default storage class, or specify your preferred class
    accessModes:
      - ReadWriteOnce
```

> **Note:** If you are upgrading an existing installation that was using the default `8Gi` PVC from v9.2.9, the existing PVC will remain attached and continue to be used. The removal of the default size only affects new installations.

##### Option 3: Use external RabbitMQ (recommended for production)

For production environments, we recommend using a managed RabbitMQ service or a separately managed RabbitMQ cluster:

```yaml
rabbitmq:
  enabled: false

onboarding:
  configmap:
    RABBITMQ_HOST: "your-rabbitmq-host:5672"
    RABBITMQ_VHOST: "/"

transaction:
  configmap:
    RABBITMQ_HOST: "your-rabbitmq-host:5672"
    RABBITMQ_VHOST: "/"
```

> **Note:** See the [Midaz Production Best Practices](https://docs.lerian.studio/docs/midaz-production-best-practices) for guidance on operating RabbitMQ in production.

#### Operational impact

- **Existing installations with PVCs:** If your v9.2.9 installation already has a RabbitMQ PVC, it will continue to be used after upgrade. No data loss will occur.
- **New installations:** Will use ephemeral storage by default. You must explicitly configure `rabbitmq.storage.requestedSize` to enable persistence.
- **Adding persistence later:** If you deploy with ephemeral storage and later want to add persistence, you must delete the RabbitMQ StatefulSet (not the pod) and redeploy:

```bash
# Back up RabbitMQ definitions first
kubectl exec -n midaz midaz-rabbitmq-0 -- rabbitmqctl export_definitions /tmp/definitions.json
kubectl cp midaz/midaz-rabbitmq-0:/tmp/definitions.json ./rabbitmq-backup.json

# Delete the StatefulSet (preserves pods)
kubectl delete statefulset midaz-rabbitmq -n midaz --cascade=orphan

# Update values.yaml with storage configuration, then upgrade
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.10 -n midaz -f values.yaml
```

> **Warning:** The above procedure will cause RabbitMQ downtime. Plan accordingly and ensure you have backed up your RabbitMQ definitions and critical messages.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.10 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.10 -n midaz
```
