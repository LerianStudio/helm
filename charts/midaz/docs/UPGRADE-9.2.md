# Helm Upgrade from v9.1.2 to v9.2.0

## Topics

- **[Features](#features)**
  - [1. Ledger init container timeout configuration](#1-ledger-init-container-timeout-configuration)
  - [2. Managed/external MongoDB validation](#2-managedexternal-mongodb-validation)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Ledger init container timeout configuration

The ledger deployment now exposes a configurable timeout for the `wait-for-dependencies` init container. This init container blocks pod startup until all ledger datastore and broker dependencies accept TCP connections, including `MONGO_CRM_HOST` and `MONGO_FEES_HOST` (regardless of `crm.enabled`, since CRM and Fees modules are folded into the ledger binary).

Previously, the timeout was hardcoded in the init container script. Now operators can tune it via `ledger.initContainer.timeoutSeconds`.

| Setting | v9.1.2 | v9.2.0 |
|---------|--------|--------|
| `ledger.initContainer.timeoutSeconds` | Not configurable (hardcoded) | `300` (default, configurable) |

**Why this matters:**

- When running on managed or external MongoDB (`mongodb.enabled=false`), you must explicitly set `MONGO_CRM_HOST` and `MONGO_FEES_HOST` (or their global equivalents). If these are not set, they default to the packaged `midaz-mongodb` Service name, which does not exist when the packaged MongoDB is disabled.
- The ledger init container hard-gates on **all 9 dependencies**, including `MONGO_CRM_HOST` and `MONGO_FEES_HOST`, regardless of whether the CRM service is enabled. If the init container cannot reach these hosts, the pod will CrashLoop after the timeout expires.
- Operators can now increase the timeout for slow-starting or remote dependencies, or decrease it for faster fail-fast behavior in development.

**Configuration example:**

```yaml
ledger:
  initContainer:
    # Per-dependency wait timeout in seconds before the init container gives
    # up (exit 1 -> pod CrashLoop). Increase for slow-starting managed databases.
    timeoutSeconds: 600
```

> **Important:** This timeout applies **per dependency check**, not as a total timeout. The init container will wait up to `timeoutSeconds` for each of the 9 dependencies to become reachable.

### 2. Managed/external MongoDB validation

A new template helper `midaz.validateManagedMongo` has been introduced to fail-fast at `helm install` or `helm upgrade` time when the operator runs on an external or managed MongoDB (`mongodb.enabled=false`) but has **not** told the ledger where the CRM and Fees MongoDB instances live.

**Why this is needed:**

The ledger ConfigMap resolves `MONGO_CRM_HOST` and `MONGO_FEES_HOST` through the `lerian-common.datastore.value` helper with a hardcoded default of `midaz-mongodb` (the packaged MongoDB Service name). When the packaged MongoDB is disabled and no host override is provided, these keys silently point at a Service that does not exist. The ledger init container `wait-for-dependencies` hard-gates on **all 9 dependencies** — including `MONGO_CRM_HOST` and `MONGO_FEES_HOST`, regardless of `crm.enabled` — so the pod never starts: it CrashLoops after `ledger.initContainer.timeoutSeconds` (default 300s).

**What changed:**

**Before (v9.1.2):**

```yaml
# No validation. If mongodb.enabled=false and MONGO_CRM_HOST / MONGO_FEES_HOST
# are not set, the ledger pod silently CrashLoops after the init timeout.
```

**After (v9.2.0):**

```yaml
# The chart now validates at template-time that if mongodb.enabled=false,
# at least one of the following must be set for CRM and Fees:
#   - global.datastores.mongoCrm.host / global.datastores.mongoFees.host
#   - ledger.datastores.mongoCrm.host / ledger.datastores.mongoFees.host
#   - ledger.configmap.MONGO_CRM_HOST / ledger.configmap.MONGO_FEES_HOST
# If not, helm install/upgrade fails with an actionable error message.
```

The validation is called early from `templates/ledger/configmap.yaml` and uses the **same** datastore resolution logic as the ConfigMap itself, so the guard and the rendered value can never disagree.

> **Note:** This is a **values-level conditional-required constraint only**. Helm template is offline and cannot check reachability. The validation ensures the host is explicitly set, not that it is reachable.

> **Warning:** `global.cloud` presets (e.g., `global.cloud: gcp`) set MongoDB **topology** (TLS, params, scheme), never the host. They do **not** satisfy this requirement. You must still set the host explicitly.

**Error message example:**

If you run `helm upgrade` with `mongodb.enabled=false` and no CRM/Fees host set, you will see:

```
Error: UPGRADE FAILED: template: midaz/templates/ledger/configmap.yaml:7:4: executing "midaz/templates/ledger/configmap.yaml" at <include "midaz.validateManagedMongo" (dict "context" $)>: error calling include: template: midaz/templates/_helpers.tpl:504:4: executing "midaz.validateManagedMongo" at <fail (printf "\n\nmidaz: managed/external Mongo is selected (mongodb.enabled=false) but the %s Mongo host is not set.\nThe ledger still needs a reachable Mongo for CRM and Fees (they are folded into the ledger binary), and the ledger init container hard-gates on MONGO_CRM_HOST and MONGO_FEES_HOST regardless of crm.enabled. With the packaged Mongo disabled and no host override, these default to the packaged Service \"midaz-mongodb\" (which is not deployed), so the ledger pod CrashLoops after ledger.initContainer.timeoutSeconds (default 300s).\n\nSet the host(s) explicitly, e.g.:\n  --set global.datastores.mongoCrm.host=<your-mongo-host> --set global.datastores.mongoFees.host=<your-mongo-host>\nor per-component:\n  ledger.datastores.mongoCrm.host / ledger.datastores.mongoFees.host\nor as a native override:\n  ledger.configmap.MONGO_CRM_HOST / ledger.configmap.MONGO_FEES_HOST\n\nSee charts/midaz/docs/UPGRADE-9.1.md section 6 (Ledger CRM and Fees module integration).\n" (join " and " $unset))>: CRM and Fees
```

## Configuration Reference

### New values

| Flag | Default | Description |
|------|---------|-------------|
| `ledger.initContainer.timeoutSeconds` | `300` | Per-dependency wait timeout in seconds before the init container gives up (exit 1 → pod CrashLoop). Increase for slow-starting managed databases or decrease for faster fail-fast in development. |

### Managed MongoDB host configuration

When `mongodb.enabled=false`, you **must** set the CRM and Fees MongoDB hosts explicitly. Choose one of the following approaches:

#### Option 1: Global datastore configuration (recommended)

```yaml
global:
  datastores:
    mongoCrm:
      host: "mongo.example.com"
    mongoFees:
      host: "mongo.example.com"
```

#### Option 2: Per-component datastore configuration

```yaml
ledger:
  datastores:
    mongoCrm:
      host: "mongo-crm.example.com"
    mongoFees:
      host: "mongo-fees.example.com"
```

#### Option 3: Native ConfigMap override

```yaml
ledger:
  configmap:
    MONGO_CRM_HOST: "mongo-crm.example.com"
    MONGO_FEES_HOST: "mongo-fees.example.com"
```

> **Note:** All three approaches are equivalent. The chart resolves them in the following precedence order: native ConfigMap override → per-component datastore → global datastore → default (`midaz-mongodb`).

## Migration Steps

### For operators using the packaged MongoDB (`mongodb.enabled=true`, default)

No action required. The chart behavior is unchanged.

### For operators using managed/external MongoDB (`mongodb.enabled=false`)

1. **Before upgrading**, ensure you have set the CRM and Fees MongoDB hosts explicitly using one of the approaches in [Configuration Reference](#configuration-reference).

2. **Verify your configuration** by running a dry-run:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm \
  --version 9.2.0 \
  -n midaz \
  --dry-run \
  --set mongodb.enabled=false \
  --set global.datastores.mongoCrm.host=<your-mongo-host> \
  --set global.datastores.mongoFees.host=<your-mongo-host>
```

3. **If the dry-run succeeds**, proceed with the upgrade. If it fails with the validation error, add the missing host configuration.

4. **(Optional)** Tune the init container timeout if your managed MongoDB instances are slow to start or located in a remote region:

```yaml
ledger:
  initContainer:
    timeoutSeconds: 600
```

### For operators who previously experienced ledger CrashLoops

If you previously encountered ledger pods stuck in CrashLoopBackOff after disabling the packaged MongoDB, this release prevents that scenario by failing early with an actionable error message. Follow the steps above to set the required hosts before upgrading.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.0 -n midaz
```
