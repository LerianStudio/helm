<!-- {% raw %} -->
# Helm Upgrade from v10.4.3 to v11.0.0

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [1. MongoDB architecture changed from standalone to replica set](#1-mongodb-architecture-changed-from-standalone-to-replica-set)
  - [2. MongoDB Service name changed for replica set deployments](#2-mongodb-service-name-changed-for-replica-set-deployments)
  - [3. MongoDB update strategy changed from Recreate to RollingUpdate](#3-mongodb-update-strategy-changed-from-recreate-to-rollingupdate)
- **[Migration Scenarios](#migration-scenarios)**
  - [Scenario 1: Upgrading with bundled MongoDB (default)](#scenario-1-upgrading-with-bundled-mongodb-default)
  - [Scenario 2: Using external MongoDB](#scenario-2-using-external-mongodb)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Breaking Changes

### 1. MongoDB architecture changed from standalone to replica set

The bundled MongoDB deployment has been changed from a standalone instance to a single-member replica set. This change enables MongoDB transactions, which are required by the ledger service to record fee quota usage atomically.

#### What changed

| Setting | v10.4.3 | v11.0.0 |
|---------|---------|---------|
| mongodb.architecture | standalone (implicit default) | replicaset |
| mongodb.replicaCount | 1 (implicit) | 1 (explicit) |
| mongodb.arbiter.enabled | N/A | false |

**Before (v10.4.3):**

```yaml
mongodb:
  resourcesPreset: "medium"
  updateStrategy:
    type: Recreate
  persistence:
    size: 8Gi
```

**After (v11.0.0):**

```yaml
mongodb:
  resourcesPreset: "medium"
  architecture: replicaset
  replicaCount: 1
  arbiter:
    enabled: false
  updateStrategy:
    type: RollingUpdate
  persistence:
    size: 8Gi
```

#### Why it matters

**Application requirement:**
- The Midaz ledger service now uses MongoDB transactions to ensure atomic updates when recording fee quota usage
- MongoDB transactions are only supported in replica set deployments, not in standalone mode
- A single-member replica set provides transaction support while maintaining the same resource footprint as a standalone instance

**Operational impact:**
- The MongoDB StatefulSet will be recreated during the upgrade to change from standalone to replica set mode
- This requires a brief downtime for the MongoDB instance while the replica set is initialized
- The existing data volume will be preserved and reused by the new replica set member

#### Migration impact

> **Warning:** Upgrading from standalone to replica set mode requires MongoDB downtime. The StatefulSet must be deleted and recreated because the `architecture` setting changes the pod labels and service configuration, which are immutable fields in Kubernetes.

> **Important:** Your existing MongoDB data will be preserved. The persistent volume claim (PVC) is retained during the upgrade and will be reattached to the new replica set member.

### 2. MongoDB Service name changed for replica set deployments

When MongoDB is deployed as a replica set, the primary Service name changes from `midaz-mongodb` to `midaz-mongodb-headless`. This is a requirement of the MongoDB Helm chart's replica set architecture, which uses a headless Service for member discovery.

#### What changed

The chart now includes a new helper template `midaz.mongodbHost` that dynamically selects the correct Service name based on the MongoDB architecture:

| Architecture | Service Name |
|--------------|--------------|
| standalone | midaz-mongodb |
| replicaset | midaz-mongodb-headless |

**Before (v10.4.3):**

All MongoDB connection strings used the static default `midaz-mongodb`:

```yaml
MONGO_HOST: {{ include "lerian-common.datastore.value" (dict "context" $ "dedicated" .Values.ledger.datastores "configmap" $cm "type" "mongoOnboarding" "field" "host" "nativeKey" "MONGO_ONBOARDING_HOST" "default" "midaz-mongodb") | quote }}
```

**After (v11.0.0):**

The default is now computed by the `midaz.mongodbHost` helper:

```yaml
MONGO_HOST: {{ include "lerian-common.datastore.value" (dict "context" $ "dedicated" .Values.ledger.datastores "configmap" $cm "type" "mongoOnboarding" "field" "host" "nativeKey" "MONGO_ONBOARDING_HOST" "default" (include "midaz.mongodbHost" $)) | quote }}
```

#### Why it matters

**Replica set requirement:**
- MongoDB replica sets require a headless Service to enable direct pod-to-pod communication for replication
- The headless Service provides stable DNS names for each replica set member (e.g., `midaz-mongodb-0.midaz-mongodb-headless`)
- The MongoDB driver uses these DNS names to discover and connect to replica set members

**Automatic configuration:**
- The chart automatically configures the correct Service name based on the `mongodb.architecture` setting
- Operators do not need to manually update connection strings in their values overrides
- The change is transparent for deployments using the bundled MongoDB with default settings

#### Migration impact

> **Note:** If you are using the bundled MongoDB with default settings, no action is required. The chart will automatically update all connection strings to use `midaz-mongodb-headless` during the upgrade.

> **Important:** If you have overridden any MongoDB host values in your `values.yaml` (e.g., `ledger.datastores.mongoOnboarding.host`), you must update them to `midaz-mongodb-headless` when upgrading to v11.0.0. See [Scenario 1](#scenario-1-upgrading-with-bundled-mongodb-default) for details.

### 3. MongoDB update strategy changed from Recreate to RollingUpdate

The MongoDB StatefulSet update strategy has been changed from `Recreate` to `RollingUpdate` to support the replica set architecture.

#### What changed

| Setting | v10.4.3 | v11.0.0 |
|---------|---------|---------|
| mongodb.updateStrategy.type | Recreate | RollingUpdate |

**Before (v10.4.3):**

```yaml
mongodb:
  updateStrategy:
    type: Recreate
```

**After (v11.0.0):**

```yaml
mongodb:
  architecture: replicaset
  updateStrategy:
    type: RollingUpdate
```

#### Why it matters

**Kubernetes requirement:**
- StatefulSets with `Recreate` strategy terminate all pods before creating new ones, causing downtime
- StatefulSets with `RollingUpdate` strategy update pods one at a time, maintaining availability
- Kubernetes StatefulSets **require** `RollingUpdate` strategy when using replica sets or multiple replicas
- The StatefulSet controller will reject a StatefulSet with `type: Recreate` if `replicas > 1` or if the pod template includes replica set configuration

**Operational benefit:**
- Future MongoDB version upgrades will be performed with zero downtime (once you scale to multiple replicas)
- The single-member replica set in v11.0.0 still experiences brief downtime during pod updates, but the configuration is now ready for horizontal scaling

#### Migration impact

> **Warning:** If you have explicitly pinned `mongodb.updateStrategy.type: Recreate` in your `values.yaml`, you **must** remove this override or change it to `RollingUpdate` before upgrading to v11.0.0. The upgrade will fail if you attempt to deploy a replica set with `Recreate` strategy.

## Migration Scenarios

### Scenario 1: Upgrading with bundled MongoDB (default)

This scenario applies if you are using the MongoDB instance bundled with the Midaz chart (the default configuration).

#### Pre-upgrade checklist

1. **Verify you are using bundled MongoDB:**

```bash
helm get values midaz -n midaz | grep -A 5 "^mongodb:"
```

If `mongodb.enabled` is not set or is `true`, you are using bundled MongoDB.

2. **Check for custom MongoDB host overrides:**

```bash
helm get values midaz -n midaz | grep -i "mongo.*host"
```

If you see any custom host values (e.g., `ledger.datastores.mongoOnboarding.host: "custom-host"`), note them for step 4.

3. **Verify your MongoDB data volume will be preserved:**

```bash
kubectl get pvc -n midaz -l app.kubernetes.io/name=mongodb
```

Confirm the PVC has `persistentVolumeReclaimPolicy: Retain` or that your storage class retains volumes by default.

#### Migration steps

**Step 1: Backup your MongoDB data (recommended)**

Before upgrading, create a backup of your MongoDB databases:

```bash
# Port-forward to MongoDB
kubectl port-forward -n midaz svc/midaz-mongodb 27017:27017 &

# Dump all databases
mongodump --host localhost --port 27017 --username midaz --password <password> --out /tmp/midaz-backup

# Stop port-forward
kill %1
```

**Step 2: Remove incompatible value overrides**

If you have explicitly set `mongodb.updateStrategy.type: Recreate` in your `values.yaml`, remove it or change it to `RollingUpdate`:

```yaml
# Remove this from your values.yaml:
mongodb:
  updateStrategy:
    type: Recreate  # ❌ Not compatible with replica sets
```

**Step 3: Prepare for MongoDB downtime**

The upgrade will cause MongoDB downtime while the StatefulSet is recreated. Plan the upgrade during a maintenance window.

**Step 4: Update custom MongoDB host overrides (if applicable)**

If you found custom MongoDB host overrides in the pre-upgrade checklist, update them in your `values.yaml`:

```yaml
# Before (v10.4.3):
ledger:
  datastores:
    mongoOnboarding:
      host: "midaz-mongodb"  # ❌ Old Service name

# After (v11.0.0):
ledger:
  datastores:
    mongoOnboarding:
      host: "midaz-mongodb-headless"  # ✅ New Service name for replica set
```

Repeat for all MongoDB modules: `mongoOnboarding`, `mongoTransaction`, `mongoCrm`, `mongoFees`.

> **Note:** If you are using the default values (no custom host overrides), skip this step. The chart will automatically use the correct Service name.

**Step 5: Perform the upgrade**

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 11.0.0 -n midaz
```

**Step 6: Monitor the MongoDB replica set initialization**

Watch the MongoDB pod restart and initialize as a replica set:

```bash
kubectl logs -n midaz -l app.kubernetes.io/name=mongodb -f
```

Wait for the log message indicating the replica set is ready:

```
[...] Replica set 'rs0' initialized successfully
```

**Step 7: Verify application connectivity**

Check that the ledger and CRM services can connect to MongoDB:

```bash
kubectl logs -n midaz -l app.kubernetes.io/name=midaz-ledger --tail=50 | grep -i mongo
kubectl logs -n midaz -l app.kubernetes.io/name=midaz-crm --tail=50 | grep -i mongo
```

Look for successful connection messages and absence of connection errors.

#### Expected downtime

- **MongoDB:** 2-5 minutes (StatefulSet recreation and replica set initialization)
- **Ledger and CRM services:** 2-5 minutes (waiting for MongoDB to become ready)

#### Rollback procedure

If the upgrade fails or you need to rollback:

```bash
# Rollback to v10.4.3
helm rollback midaz -n midaz

# If MongoDB data is corrupted, restore from backup
kubectl port-forward -n midaz svc/midaz-mongodb 27017:27017 &
mongorestore --host localhost --port 27017 --username midaz --password <password> /tmp/midaz-backup
kill %1
```

> **Important:** After rollback, you must manually change the MongoDB architecture back to standalone by setting `mongodb.architecture: standalone` in your `values.yaml`, or the next upgrade attempt will fail.

### Scenario 2: Using external MongoDB

This scenario applies if you have disabled the bundled MongoDB and are using an external MongoDB instance.

#### Pre-upgrade checklist

1. **Verify you are using external MongoDB:**

```bash
helm get values midaz -n midaz | grep "mongodb:" -A 2
```

If `mongodb.enabled: false`, you are using external MongoDB.

2. **Verify your external MongoDB supports transactions:**

Connect to your external MongoDB instance and check the deployment mode:

```bash
mongo --host <external-host> --port <external-port> -u <user> -p <password> --eval "rs.status()"
```

If the command returns replica set status, your MongoDB supports transactions. If it returns an error like "not running with --replSet", your MongoDB is in standalone mode and does **not** support transactions.

#### Migration steps

**If your external MongoDB is already a replica set:**

No action is required. The Midaz application will automatically use transactions when connecting to your external replica set.

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 11.0.0 -n midaz
```

**If your external MongoDB is standalone:**

> **Warning:** The Midaz ledger service requires MongoDB transactions starting in v11.0.0. You must migrate your external MongoDB from standalone to replica set mode before upgrading the Midaz chart.

1. **Convert your external MongoDB to a replica set:**

Follow the MongoDB documentation to convert a standalone instance to a single-member replica set:

https://docs.mongodb.com/manual/tutorial/convert-standalone-to-replica-set/

2. **Update your connection strings (if necessary):**

If your external MongoDB uses a different hostname for replica set connections, update the host values in your `values.yaml`:

```yaml
ledger:
  datastores:
    mongoOnboarding:
      host: "external-mongodb-replica-set.example.com"
    mongoTransaction:
      host: "external-mongodb-replica-set.example.com"
    mongoCrm:
      host: "external-mongodb-replica-set.example.com"
    mongoFees:
      host: "external-mongodb-replica-set.example.com"

crm:
  datastores:
    mongo:
      host: "external-mongodb-replica-set.example.com"
```

3. **Perform the upgrade:**

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 11.0.0 -n midaz
```

#### Expected downtime

- **Bundled components:** None (external MongoDB is not affected by the chart upgrade)
- **External MongoDB conversion:** Varies depending on your MongoDB deployment method (typically 5-15 minutes for a standalone-to-replica-set conversion)

## Configuration Reference

### MongoDB replica set configuration

The following values control the MongoDB replica set deployment:

```yaml
mongodb:
  # Enable or disable the bundled MongoDB instance
  enabled: true
  
  # MongoDB deployment architecture
  # Options: standalone, replicaset
  # Default: replicaset (changed in v11.0.0)
  architecture: replicaset
  
  # Number of MongoDB replica set members
  # For v11.0.0, this is set to 1 (single-member replica set)
  replicaCount: 1
  
  # Arbiter configuration (not used in single-member replica sets)
  arbiter:
    enabled: false
  
  # Update strategy for the MongoDB StatefulSet
  # Must be RollingUpdate for replica sets
  updateStrategy:
    type: RollingUpdate
  
  # Persistent storage configuration
  persistence:
    size: 8Gi
    # The data volume outlives the release
    resourcePolicy: keep
  
  # Resource allocation
  resourcesPreset: "medium"
```

| Flag | Default | Description |
|------|---------|-------------|
| mongodb.architecture | replicaset | MongoDB deployment mode. Must be `replicaset` for transaction support. |
| mongodb.replicaCount | 1 | Number of data-bearing replica set members. Single member provides transactions without replication overhead. |
| mongodb.arbiter.enabled | false | Whether to deploy an arbiter node. Not needed for single-member replica sets. |
| mongodb.updateStrategy.type | RollingUpdate | StatefulSet update strategy. Required to be `RollingUpdate` for replica sets. |

### MongoDB connection configuration

The chart automatically configures the correct MongoDB Service name based on the architecture. Operators using custom datastores can override the host:

```yaml
ledger:
  datastores:
    mongoOnboarding:
      # Override the MongoDB host for the onboarding module
      # Default: midaz-mongodb-headless (for replica sets)
      host: "custom-mongodb-host.example.com"
      port: "27017"
      user: "midaz"
      name: "onboarding"
    
    mongoTransaction:
      # Override the MongoDB host for the transaction module
      host: "custom-mongodb-host.example.com"
      port: "27017"
      user: "midaz"
      name: "transaction"
    
    mongoCrm:
      # Override the MongoDB host for the CRM module
      host: "custom-mongodb-host.example.com"
      port: "27017"
      user: "midaz"
      name: "crm"
    
    mongoFees:
      # Override the MongoDB host for the fees module
      host: "custom-mongodb-host.example.com"
      port: "27017"
      user: "midaz"
      name: "fees"

crm:
  datastores:
    mongo:
      # Override the MongoDB host for the standalone CRM service
      host: "custom-mongodb-host.example.com"
      port: "27017"
      user: "midaz"
```

> **Note:** When using the bundled MongoDB with default settings, you do not need to set these values. The chart will automatically use `midaz-mongodb-headless` for replica sets and `midaz-mongodb` for standalone deployments.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.0.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.0.0
```
<!-- {% endraw %} -->
