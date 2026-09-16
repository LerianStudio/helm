# Helm Upgrade from v4.0.4 to v4.0.5

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. MongoDB connection defaults now resolve the bundled subchart](#1-mongodb-connection-defaults-now-resolve-the-bundled-subchart)
  - [2. MongoDB password automatically wired from subchart Secret](#2-mongodb-password-automatically-wired-from-subchart-secret)
  - [3. Readiness probe default changed back to MongoDB-independent endpoint](#3-readiness-probe-default-changed-back-to-mongodb-independent-endpoint)
  - [4. Namespace split detection and validation](#4-namespace-split-detection-and-validation)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
  - [Scenario 1: Default installation (bundled MongoDB, same namespace)](#scenario-1-default-installation-bundled-mongodb-same-namespace)
  - [Scenario 2: Bundled MongoDB with namespace split](#scenario-2-bundled-mongodb-with-namespace-split)
  - [Scenario 3: External MongoDB](#scenario-3-external-mongodb)
  - [Scenario 4: Custom MongoDB architecture or Service name](#scenario-4-custom-mongodb-architecture-or-service-name)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that fixes MongoDB connection defaults and password wiring for the bundled subchart. The application version is unchanged.

| Field | v4.0.4 | v4.0.5 |
|-------|--------|--------|
| Chart version | `4.0.4` | `4.0.5` |
| App version | `1.12.0` | `1.12.0` |

## Fixes

### 1. MongoDB connection defaults now resolve the bundled subchart

The default value for `configmap.MONGO_HOST` has been fixed to resolve the bundled MongoDB subchart's actual Service name instead of pointing at a hardcoded `"mongodb"` that does not exist in the release.

| Setting | v4.0.4 | v4.0.5 |
|---------|--------|--------|
| `configmap.MONGO_HOST` (default) | `"mongodb"` (does not exist) | `<release-name>-mongodb.<namespace>.svc.cluster.local` (resolved dynamically) |

**What changed:**

The chart now computes the MongoDB Service FQDN using the same name resolution rules the Bitnami subchart applies: `fullnameOverride` wins, else `nameOverride`, else `<release-name>-mongodb`, with the release name collapsing when it already contains `mongodb` (e.g. `helm install mongodb` creates Service `mongodb`, not `mongodb-mongodb`).

**Impact:**

- Default installations now connect to the bundled MongoDB without requiring an explicit `configmap.MONGO_HOST` override
- If you previously set `configmap.MONGO_HOST` to work around the broken default, you can remove that override after upgrading
- The chart now **refuses to render** in two unsupported topologies unless you explicitly set `configmap.MONGO_HOST`:
  - `mongodb.architecture` is not `standalone` (e.g. `replicaset`): the subchart publishes a headless Service and per-replica DNS names instead of a single Service, so there is no single correct default
  - `mongodb.service.nameOverride` is set: the subchart's Service carries a custom name, so the default would point at a Service that does not exist

**Example error when using replicaset architecture:**

```
product-console: mongodb.architecture is replicaset, so the bundled MongoDB publishes the headless Service <release-name>-mongodb-headless.<namespace>.svc.cluster.local and one DNS name per replica rather than a single Service, and configmap.MONGO_HOST has no correct default. Set configmap.MONGO_HOST to <release-name>-mongodb-headless.<namespace>.svc.cluster.local, and add replicaSet=rs0 to configmap.MONGO_PARAMETERS so the driver reads the whole replica set.
```

### 2. MongoDB password automatically wired from subchart Secret

The console now reads the MongoDB root password directly from the subchart's generated Secret when both resources land in the same namespace, eliminating the need to manually copy a generated password into `secrets.MONGODB_PASS`.

**What changed:**

The Deployment template now injects an explicit `MONGODB_PASS` environment variable that reads from the subchart's Secret (key `mongodb-root-password`) when all of the following conditions are met:

- `mongodb.enabled` is `true`
- `mongodb.auth.enabled` is `true` (default)
- `secrets.MONGODB_PASS` is empty (default)
- `useExistingSecret` is not set
- The console pods and the MongoDB subchart land in the same namespace

**Before (v4.0.4):**

```yaml
# Deployment template
envFrom:
  - configMapRef:
      name: product-console
  - secretRef:
      name: product-console  # MONGODB_PASS="" unless operator fills it
```

**After (v4.0.5):**

```yaml
# Deployment template (when conditions are met)
env:
  - name: MONGODB_PASS
    valueFrom:
      secretKeyRef:
        name: <release-name>-mongodb  # or mongodb.auth.existingSecret
        key: mongodb-root-password
envFrom:
  - configMapRef:
      name: product-console
  - secretRef:
      name: product-console  # MONGODB_PASS="" is now overridden by env entry above
```

**Impact:**

- Default installations no longer require setting `secrets.MONGODB_PASS` manually
- The wiring is **skipped** when:
  - You set `secrets.MONGODB_PASS` or `useExistingSecret` (your value takes precedence)
  - `mongodb.auth.enabled` is `false` (no password needed)
  - The console and MongoDB land in different namespaces (Secrets cannot be read across namespaces)

> **Important:** If the console and MongoDB subchart land in different namespaces (via `global.namespaceOverride` or a different `-n` flag), the password cannot be wired automatically. The chart's install notes will detect this and print instructions to set both `mongodb.auth.rootPassword` and `secrets.MONGODB_PASS` to the same value.

### 3. Readiness probe default changed back to MongoDB-independent endpoint

The readiness probe default path has been changed from `/api/admin/health/readyz` back to `/api/admin/health/alive` to prevent deadlock on fresh installations with the current application image.

| Probe | v4.0.4 | v4.0.5 |
|-------|--------|--------|
| `readinessProbe.path` (default) | `/api/admin/health/readyz` | `/api/admin/health/alive` |
| `livenessProbe.path` (default) | `/` | `/` (unchanged) |

**Why this matters:**

The application image this chart pins (`1.12.0`) connects to MongoDB **on the first request that needs it**, not at startup. With readiness on `/api/admin/health/readyz` (which gates on MongoDB connection), a fresh pod deadlocks:

1. Pod is not Ready, so the Service sends no traffic
2. No traffic means no MongoDB connection is opened
3. `readyz` stays `503` because there is no connection
4. Pod never becomes Ready

Measured behavior on `lerianstudio/product-console:1.12.0`: `readyz` returns `503` (readyState=0) indefinitely until the first request to a Mongo-backed route, then turns `200` within three seconds.

**Impact:**

- Fresh installations no longer deadlock on readiness
- Readiness does **not** gate on MongoDB by default
- The `/api/admin/health/alive` endpoint returns `200` as soon as the server answers, with no database dependency

> **Note:** If you run an application image that connects to MongoDB **at startup** (not on first request), set `readinessProbe.path: /api/admin/health/readyz` to have readiness gate on the database again. The chart's install notes and `values.yaml` comments now document this explicitly.

> **Warning:** Keep liveness on a MongoDB-independent endpoint. Pointing it at `readyz` or any Mongo-dependent path turns a database outage into a crash-loop.

### 4. Namespace split detection and validation

The chart now detects when the console pods and the MongoDB subchart land in different namespaces and prints actionable instructions in the install notes.

**What changed:**

Three new template helpers were added to track the MongoDB subchart's actual namespace and Secret name:

- `product-console.mongodb.namespace`: resolves `global.namespaceOverride` (which the subchart reads) or the release namespace
- `product-console.mongodb.fullname`: resolves the subchart's Service and Secret name following Bitnami's own rules
- `product-console.mongodb.secretName`: resolves `mongodb.auth.existingSecret` or the generated Secret name

The install notes now compare the console's namespace (from `namespaceOverride` or release namespace) with the subchart's namespace and print one of three messages:

1. **Same namespace, password wired automatically:** "The credential is wired for you. The console reads MONGODB_PASS from key 'mongodb-root-password' of the Secret the subchart runs with."
2. **Different namespaces, action required:** "ACTION REQUIRED, or every Mongo-backed page fails on an auth error. The subchart's password lives in Secret '<name>', in namespace '<namespace>', while these pods run in '<namespace>'. A Secret cannot be read across namespaces..."
3. **Operator supplied password:** "The console uses the MONGODB_PASS you supplied. It must be the password the subchart actually runs with..."

**Impact:**

- Operators are warned before deployment when the namespace split will break password wiring
- The install notes print the exact values to set (`mongodb.auth.rootPassword` and `secrets.MONGODB_PASS`) when manual configuration is required

## Configuration Changes

No existing keys were removed or renamed. New template helpers and expanded documentation were added.

| Setting | v4.0.4 | v4.0.5 | Notes |
|---------|--------|--------|-------|
| `configmap.MONGO_HOST` (default) | `"mongodb"` | Resolved dynamically | Now points at the subchart's actual Service FQDN |
| `readinessProbe.path` (default) | `/api/admin/health/readyz` | `/api/admin/health/alive` | Changed to prevent deadlock with lazy MongoDB connection |
| `secrets.MONGODB_PASS` (default) | `""` | `""` (unchanged) | Now auto-wired from subchart Secret when in same namespace |

**New template helpers:**

| Helper | Description |
|--------|-------------|
| `product-console.mongodb.fullname` | Resolves the subchart's Service and Secret name |
| `product-console.mongodb.namespace` | Resolves the namespace the subchart lands in |
| `product-console.mongodb.secretName` | Resolves the Secret name holding the root password |
| `product-console.mongodb.host` | Resolves the default MONGO_HOST value |

**Expanded documentation:**

- `values.yaml` now includes detailed comments for `readinessProbe`, `livenessProbe`, `configmap`, `extraEnvVars`, and `secrets.MONGODB_PASS`
- `NOTES.txt` now includes a "Readiness / MongoDB requirement" section explaining the probe defaults and when to change them
- `NOTES.txt` now detects and explains namespace splits with actionable remediation steps

## Migration Steps

### Scenario 1: Default installation (bundled MongoDB, same namespace)

If you are using the bundled MongoDB subchart with default settings and installing into the chart's own namespace (`-n product-console`), no changes are required.

**Before (v4.0.4):**

```yaml
# values.yaml or --set flags
mongodb:
  enabled: true

# You may have set this to work around the broken default:
configmap:
  MONGO_HOST: "product-console-mongodb"
```

**After (v4.0.5):**

```yaml
# values.yaml or --set flags
mongodb:
  enabled: true

# Remove the MONGO_HOST override — the default now works:
# configmap:
#   MONGO_HOST: "product-console-mongodb"
```

**Steps:**

1. Remove any `configmap.MONGO_HOST` override from your values file or `--set` flags
2. Run the upgrade command
3. Verify pods are running and connecting to MongoDB:

```bash
kubectl get pods -n product-console
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50 | grep -i mongo
```

### Scenario 2: Bundled MongoDB with namespace split

If you set `global.namespaceOverride` or install with `-n <namespace>` that differs from the chart's `namespaceOverride`, the console and MongoDB land in different namespaces and the password cannot be wired automatically.

**Before (v4.0.4):**

```yaml
# values.yaml
global:
  namespaceOverride: "databases"

mongodb:
  enabled: true
  auth:
    rootPassword: ""  # Generated randomly

secrets:
  MONGODB_PASS: ""  # Empty, so auth fails
```

**After (v4.0.5):**

```yaml
# values.yaml
global:
  namespaceOverride: "databases"

mongodb:
  enabled: true
  auth:
    rootPassword: "your-secure-password"  # Set explicitly

secrets:
  MONGODB_PASS: "your-secure-password"  # Must match rootPassword
```

**Steps:**

1. Choose a secure password
2. Set **both** `mongodb.auth.rootPassword` and `secrets.MONGODB_PASS` to the same value
3. Run the upgrade command
4. Verify the install notes confirm the password is supplied:

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.0.5 \
  --set mongodb.auth.rootPassword="your-secure-password" \
  --set secrets.MONGODB_PASS="your-secure-password" \
  -n product-console
```

> **Important:** The two passwords must match exactly, or every Mongo-backed page (product enablement, guided tour) will fail with an authentication error.

**Alternative:** Clear `global.namespaceOverride` or set it to match the console's namespace to restore automatic wiring:

```yaml
# values.yaml
global:
  namespaceOverride: "product-console"  # Same as chart's namespaceOverride

mongodb:
  enabled: true
  # auth.rootPassword can be left empty — generated automatically
```

### Scenario 3: External MongoDB

If you are using an external MongoDB (not the bundled subchart), no changes are required. The chart continues to use the `configmap.MONGO_HOST` you set.

**Before (v4.0.4):**

```yaml
# values.yaml
mongodb:
  enabled: false

configmap:
  MONGO_HOST: "mongodb.external.svc.cluster.local"

secrets:
  MONGODB_PASS: "external-db-password"
```

**After (v4.0.5):**

```yaml
# values.yaml (unchanged)
mongodb:
  enabled: false

configmap:
  MONGO_HOST: "mongodb.external.svc.cluster.local"

secrets:
  MONGODB_PASS: "external-db-password"
```

**Steps:**

1. Run the upgrade command with no values changes
2. Verify pods are running and connecting to the external MongoDB:

```bash
kubectl get pods -n product-console
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50 | grep -i mongo
```

### Scenario 4: Custom MongoDB architecture or Service name

If you set `mongodb.architecture` to `replicaset` or `mongodb.service.nameOverride`, the chart now **refuses to render** until you explicitly set `configmap.MONGO_HOST`.

**Example: Replicaset architecture**

```yaml
# values.yaml
mongodb:
  enabled: true
  architecture: replicaset
  replicaSetName: rs0
```

**Error on upgrade:**

```
product-console: mongodb.architecture is replicaset, so the bundled MongoDB publishes the headless Service product-console-mongodb-headless.product-console.svc.cluster.local and one DNS name per replica rather than a single Service, and configmap.MONGO_HOST has no correct default. Set configmap.MONGO_HOST to product-console-mongodb-headless.product-console.svc.cluster.local, and add replicaSet=rs0 to configmap.MONGO_PARAMETERS so the driver reads the whole replica set.
```

**Steps:**

1. Set `configmap.MONGO_HOST` to the headless Service FQDN printed in the error
2. Add `replicaSet=<name>` to `configmap.MONGO_PARAMETERS` so the MongoDB driver reads the replica set
3. Run the upgrade command:

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.0.5 \
  --set configmap.MONGO_HOST="product-console-mongodb-headless.product-console.svc.cluster.local" \
  --set configmap.MONGO_PARAMETERS="replicaSet=rs0" \
  -n product-console
```

**Example: Custom Service name**

```yaml
# values.yaml
mongodb:
  enabled: true
  service:
    nameOverride: "custom-mongo-svc"
```

**Error on upgrade:**

```
product-console: mongodb.service.nameOverride is custom-mongo-svc, so the bundled MongoDB's Service is named custom-mongo-svc and the configmap.MONGO_HOST default would name a Service the release does not create. Set configmap.MONGO_HOST to custom-mongo-svc.product-console.svc.cluster.local.
```

**Steps:**

1. Set `configmap.MONGO_HOST` to the custom Service FQDN printed in the error
2. Run the upgrade command:

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.0.5 \
  --set configmap.MONGO_HOST="custom-mongo-svc.product-console.svc.cluster.local" \
  -n product-console
```

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.5 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.0.5 -n product-console
```
