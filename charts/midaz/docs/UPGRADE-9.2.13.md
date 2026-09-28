# Helm Upgrade from v9.2.12 to v9.2.13

## Topics

- **[Fixes](#fixes)**
  - [1. PostgreSQL and MongoDB image digests pinned](#1-postgresql-and-mongodb-image-digests-pinned)
  - [2. MongoDB updateStrategy set to Recreate](#2-mongodb-updatestrategy-set-to-recreate)
  - [3. RabbitMQ ledger users downgraded from administrator to management](#3-rabbitmq-ledger-users-downgraded-from-administrator-to-management)
  - [4. RabbitMQ bootstrap job prevents admin user collision](#4-rabbitmq-bootstrap-job-prevents-admin-user-collision)
  - [5. ConfigMap changes now trigger pod restarts](#5-configmap-changes-now-trigger-pod-restarts)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. PostgreSQL and MongoDB image digests pinned

The PostgreSQL and MongoDB images now include pinned SHA256 digests to prevent unintended major version upgrades when using the `latest` tag.

| Setting | v9.2.12 | v9.2.13 |
|---------|---------|---------|
| `postgresql.image.digest` | (not set) | `sha256:7045d816bdf7e704f0f662fabf243f3c0a975aa380e73e4e881ee94740f60d4f` |
| `mongodb.image.digest` | (not set) | `sha256:c8babafb7d15a7412543a9a391ffee8ba206c4d10dd6a1ba2ae2bf74fdfe538b` |

**Why this matters:**

PostgreSQL and MongoDB refuse to start when the data directory was created by a different major version. Pinning the digest ensures that `latest` resolves to a known version (PostgreSQL 18.6.0, MongoDB 8.3.11) until you explicitly upgrade the chart and change the digest.

**After (v9.2.13):**

```yaml
postgresql:
  image:
    repository: bitnamisecure/postgresql
    tag: "latest"
    digest: "sha256:7045d816bdf7e704f0f662fabf243f3c0a975aa380e73e4e881ee94740f60d4f"

mongodb:
  image:
    repository: bitnamisecure/mongodb
    tag: "latest"
    digest: "sha256:c8babafb7d15a7412543a9a391ffee8ba206c4d10dd6a1ba2ae2bf74fdfe538b"
```

> **Warning:** The digest takes precedence over every other image setting. The Bitnami subcharts render `<registry>/<repository>@<digest>` whenever a digest is set, so an override of `image.tag`, `image.repository`, `image.registry` or `global.imageRegistry` no longer selects the image on its own. For example, `postgresql.image.tag: 17.6.0` renders `docker.io/bitnamisecure/postgresql@sha256:7045…` (PostgreSQL 18.6.0), and `global.imageRegistry: myreg.example.com` renders `myreg.example.com/bitnamisecure/postgresql@sha256:7045…`. The result is either an image pull failure (the digest does not exist in your repository or mirror) or a different major version that refuses your data directory.

#### Action required

- **If you override the PostgreSQL or MongoDB image** (tag, repository, registry or `global.imageRegistry`), clear the digest so your override applies again:

  ```yaml
  postgresql:
    image:
      tag: "17.6.0"   # your pinned version
      digest: ""
  mongodb:
    image:
      tag: "8.0.12"   # your pinned version
      digest: ""
  ```

- **If you run the default `latest` tag**, check the major version your bundled databases run today before upgrading. The image reference changes from `latest` to the digest, so the pods are recreated on PostgreSQL 18.6.0 and MongoDB 8.3.11. If the data directory is not on 18, set `postgresql.image.tag` to your current version with `postgresql.image.digest: ""`:

  ```bash
  # major version of the PostgreSQL data directory
  kubectl -n midaz exec <release>-postgresql-primary-0 -- cat /bitnami/postgresql/data/PG_VERSION
  kubectl -n midaz exec deploy/<release>-mongodb -- mongod --version
  ```

- **Plan a maintenance window:** because the image reference changes, this upgrade restarts the PostgreSQL primary and read replica StatefulSets and the MongoDB pod. The ledger cannot reach the database while they restart.

### 2. MongoDB updateStrategy set to Recreate

The MongoDB deployment now uses `Recreate` update strategy instead of the default `RollingUpdate`.

| Setting | v9.2.12 | v9.2.13 |
|---------|---------|---------|
| `mongodb.updateStrategy.type` | (default: `RollingUpdate`) | `Recreate` |

**Why this matters:**

A new MongoDB pod cannot open the data directory while the old pod still holds it. With `RollingUpdate`, the new pod would crash-loop until the old pod terminates. `Recreate` ensures the old pod stops before the new one starts, preventing this issue.

**After (v9.2.13):**

```yaml
mongodb:
  updateStrategy:
    type: Recreate
```

> **Warning:** The default is not adjusted for StatefulSets. With `mongodb.architecture: replicaset` or `mongodb.useStatefulSet: true`, the chart renders the MongoDB StatefulSet with `updateStrategy.type: Recreate`, which Kubernetes rejects (a StatefulSet accepts only `RollingUpdate` or `OnDelete`), and the upgrade fails.

#### Action required

If you use `mongodb.architecture: replicaset` or `mongodb.useStatefulSet: true`, set the strategy back before upgrading:

```yaml
mongodb:
  updateStrategy:
    type: RollingUpdate
```

With the default standalone Deployment, `Recreate` stops the old MongoDB pod before starting the new one, so MongoDB is unavailable for the duration of every pod replacement.

### 3. RabbitMQ ledger users downgraded from administrator to management

The RabbitMQ `consumer` user now receives the `management` tag instead of `administrator`. On an external broker (`global.externalRabbitmqDefinitions.enabled: true`) the `transaction` user is downgraded to `management` too; on the bundled broker it stays `administrator`, because the bootstrap Job logs in as `transaction`.

| User | v9.2.12 Tags | v9.2.13 Tags |
|------|--------------|--------------|
| `transaction` | `administrator` | `administrator` (bundled) / `management` (external) |
| `consumer` | `administrator` | `management` |

**Why this matters:**

The ledger services only need management-level access (view queues, publish/consume messages). Granting `administrator` privileges was excessive and violated the principle of least privilege.

**Before (v9.2.12):**

```yaml
users:
  - name: transaction
    password: <password>
    tags: administrator
  - name: consumer
    password: <password>
    tags: administrator
```

**After (v9.2.13):**

```yaml
users:
  - name: transaction
    password: <password>
    tags: administrator  # or management for external broker
  - name: consumer
    password: <password>
    tags: management
```

> **Note:** This change is applied automatically by the `bootstrap-rabbitmq` Job on upgrade. No manual intervention is required unless you manage RabbitMQ users outside the chart.

### 4. RabbitMQ bootstrap job prevents admin user collision

The RabbitMQ bootstrap Job now validates that the external broker admin user is not named `transaction` or `consumer`.

**Why this matters:**

If you configure `global.externalRabbitmqDefinitions.rabbitmqAdminLogin` to `transaction` or `consumer`, the bootstrap Job would overwrite that user's tags to `management`, effectively demoting your admin account. This validation prevents accidental lockout.

**After (v9.2.13):**

```bash
case "$RABBITMQ_ADMIN_USER" in transaction|consumer)
  echo "The broker admin login global.externalRabbitmqDefinitions.rabbitmqAdminLogin is $RABBITMQ_ADMIN_USER, a ledger user this Job would demote to management; log in with a separate admin account on the broker."
  exit 1;;
esac
```

> **Warning:** If you currently use `transaction` or `consumer` as your external RabbitMQ admin username, the upgrade will fail. Create a separate admin account (e.g., `admin`, `rabbitmq-admin`) and update `global.externalRabbitmqDefinitions.rabbitmqAdminLogin` before upgrading.

**Migration steps:**

1. Create a new admin user on your external RabbitMQ broker:

```bash
rabbitmqctl add_user admin <secure-password>
rabbitmqctl set_user_tags admin administrator
rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
```

2. Update your `values.yaml`:

```yaml
global:
  externalRabbitmqDefinitions:
    rabbitmqAdminLogin:
      username: admin
      password: <secure-password>
      # or, from a Secret with keys RABBITMQ_ADMIN_USER and RABBITMQ_ADMIN_PASS:
      # useExistingSecret:
      #   name: my-rabbitmq-admin
```

3. Proceed with the upgrade.

### 5. ConfigMap changes now trigger pod restarts

The ledger, CRM, and tracer Deployments now include a `checksum/config` annotation that triggers pod restarts when their ConfigMaps change.

| Component | v9.2.12 | v9.2.13 |
|-----------|---------|---------|
| `ledger` | `checksum/secret` only | `checksum/secret` + `checksum/config` |
| `crm` | `checksum/secret` only | `checksum/secret` + `checksum/config` |
| `tracer` | `checksum/secret` only | `checksum/secret` + `checksum/config` |

**Why this matters:**

Previously, changing a ConfigMap value (e.g., `REDIS_HOST`, `LOG_LEVEL`) required manually restarting pods with `kubectl rollout restart`. Now, Helm automatically restarts pods when the ConfigMap content changes.

**After (v9.2.13):**

```yaml
metadata:
  annotations:
    checksum/secret: {{ include (print $.Template.BasePath "/ledger/secrets.yaml") . | sha256sum }}
    checksum/config: {{ include (print $.Template.BasePath "/ledger/configmap.yaml") . | sha256sum }}
```

> **Note:** This change applies to the `ledger`, `crm`, and `tracer` Deployments, the only Deployments this chart renders from its own templates. The first upgrade to v9.2.13 restarts their pods once.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.13 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.13 -n midaz
```
