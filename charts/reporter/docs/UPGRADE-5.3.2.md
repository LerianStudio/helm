# Helm Upgrade from v5.3.1 to v5.3.2

## Topics

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. DocumentDB certificate verification on AWS](#1-documentdb-certificate-verification-on-aws)
  - [2. Pod template labels and checksum annotations](#2-pod-template-labels-and-checksum-annotations)
  - [3. Extra volumes for manager and worker](#3-extra-volumes-for-manager-and-worker)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release. The application version stays at `4.8.0`. No value is renamed or removed, and the upgrade needs no action before it, unless you use `global.cloud: aws` with a MongoDB certificate that the AWS RDS CA does not issue (see [Migration Steps](#migration-steps)).

| Field | v5.3.1 | v5.3.2 |
|-------|--------|--------|
| Chart version | `5.3.1` | `5.3.2` |
| App version | `4.8.0` | `4.8.0` |

## Changes

### 1. DocumentDB certificate verification on AWS

With `global.cloud: aws`, the chart no longer adds `tlsInsecure=true` to `MONGO_PARAMETERS` for the manager and the worker. The application checks the DocumentDB certificate against the AWS RDS CA bundle that is in its image.

| Setting | v5.3.1 | v5.3.2 |
|---------|--------|--------|
| `MONGO_PARAMETERS` with `global.cloud: aws` | `tls=true&tlsInsecure=true&directConnection=true&retryWrites=false&connectTimeoutMS=10000&serverSelectionTimeoutMS=10000` | `tls=true&directConnection=true&retryWrites=false&connectTimeoutMS=10000&serverSelectionTimeoutMS=10000` |

- This change applies only when `MONGO_PARAMETERS` resolves to the AWS preset. A different value that you set in `common.configmap.MONGO_PARAMETERS`, `datastores.mongo.params` or `global.datastores.mongo.params` renders unchanged.
- The chart keeps `tlsInsecure=true` when a pinned worker image tag is below `4.7.0` (pre-releases of `4.7.0` count as `4.7.0`). A tag that is not a version, such as `latest` or a digest, counts as new.
- With `global.cloud` unset, `gcp` or `azure`, `MONGO_PARAMETERS` does not change.

### 2. Pod template labels and checksum annotations

- The manager pod template, and the worker pod template when KEDA is disabled, no longer carry the `helm.sh/chart` label. The pod selectors are not changed.
- The `checksum/config` and `checksum/secret` annotations are now computed from the ConfigMap and Secret data only.

Because the pod template changes, the manager pods (and the worker Deployment pods when KEDA is disabled) restart once during this upgrade. With the default KEDA ScaledJob, the worker Job template does not change, so running worker Jobs are not restarted.

### 3. Extra volumes for manager and worker

New optional values `manager.extraVolumes`, `manager.extraVolumeMounts`, `worker.extraVolumes` and `worker.extraVolumeMounts` add volumes and mounts to the pods (for example, a catalog directory for `REGULATORY_CATALOG_DIR`). They default to empty lists. The `REGULATORY_CATALOG_CHANNEL`, `REGULATORY_CATALOG_DIR`, `REGULATORY_CATALOG_GITHUB_REPO` and `REGULATORY_CATALOG_GITHUB_URL` keys are now accepted in `configmap` overrides.

## Migration Steps

No action is needed before the upgrade, with one exception. With `global.cloud: aws`, if your MongoDB server certificate is not issued by the AWS RDS CA or a public CA, set `global.datastores.mongo.params` or `common.configmap.MONGO_PARAMETERS` to the parameters your server needs before you upgrade. An explicit value renders unchanged.

If you run on AWS with DocumentDB, check after the upgrade that the manager and worker pods start and connect to the database. With the default KEDA ScaledJob, worker pods exist only while a report Job runs. They carry the `scaledjob.keda.sh/name` label, not `app.kubernetes.io/name`:

```bash
kubectl get pods -n <namespace>
kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
# Worker, default KEDA ScaledJob; with KEDA disabled use -l app.kubernetes.io/name=reporter-worker
kubectl logs -n <namespace> -l scaledjob.keda.sh/name=reporter-worker --tail=50
```

> **Note:** Existing infrastructure components (MongoDB, RabbitMQ, Valkey) are not affected.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.3.2 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 5.3.2 -n <namespace>
```
