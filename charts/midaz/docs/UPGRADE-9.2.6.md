# Helm Upgrade from v9.2.5 to v9.2.6

## Topics

- **[Fixes](#fixes)**
  - [1. Datastore password Secrets now persist across uninstall/reinstall](#1-datastore-password-secrets-now-persist-across-uninstallreinstall)
  - [2. MongoDB data volume now persists across uninstall/reinstall](#2-mongodb-data-volume-now-persists-across-uninstallreinstall)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Datastore password Secrets now persist across uninstall/reinstall

**What changed:**

The chart now creates dedicated Secrets for PostgreSQL and MongoDB passwords with the `helm.sh/resource-policy: keep` annotation. These Secrets persist across `helm uninstall` and allow a same-name reinstall to reopen existing data volumes without password mismatches.

**Why it matters:**

Previously, when using the bundled PostgreSQL or MongoDB subcharts without an `existingSecret` override, uninstalling the release would delete the auto-generated password Secrets. Reinstalling with the same release name would generate new random passwords, making the persisted data volumes inaccessible (authentication failure).

This fix ensures that:
- Password Secrets survive `helm uninstall` (matching the behavior of the data PVCs, which already had `resourcePolicy: keep`)
- A reinstall with the same name reuses the kept Secrets and successfully authenticates against the existing databases
- Operators who want to provide their own Secrets can still override via `postgresql.auth.existingSecret` or `mongodb.auth.existingSecret`

**How it works:**

The chart now renders a new template `templates/datastore-secrets.yaml` that creates Secrets for PostgreSQL and MongoDB **only when**:
- The subchart is enabled (`postgresql.enabled: true` or `mongodb.enabled: true`)
- No operator-provided `existingSecret` is configured

The Secret names and keys match exactly what the Bitnami subcharts expect, so the subcharts consume them transparently.

**Before (v9.2.5):**

Subcharts generated their own Secrets, which were deleted on `helm uninstall`. No parent-chart Secret existed.

**After (v9.2.6):**

The parent chart creates and keeps the Secrets:

```yaml
# templates/datastore-secrets.yaml (PostgreSQL example)
apiVersion: v1
kind: Secret
metadata:
  name: midaz-postgresql
  annotations:
    helm.sh/resource-policy: keep
type: Opaque
data:
  postgres-password: <base64-encoded>
  password: <base64-encoded>
  replication-password: <base64-encoded>
```

```yaml
# templates/datastore-secrets.yaml (MongoDB example)
apiVersion: v1
kind: Secret
metadata:
  name: midaz-mongodb
  annotations:
    helm.sh/resource-policy: keep
type: Opaque
data:
  mongodb-root-password: <base64-encoded>
  mongodb-replica-set-key: <base64-encoded>
```

The subcharts are configured to use these Secrets via a new `existingSecret` default:

| Setting | v9.2.5 | v9.2.6 |
|---------|--------|--------|
| `postgresql.auth.existingSecret` | `""` (subchart generates Secret) | `'{{ if eq .Chart.Name "postgresql" }}{{ include "common.names.fullname" . }}{{ end }}'` (parent-chart Secret) |
| `mongodb.auth.existingSecret` | `""` (subchart generates Secret) | `'{{ if eq .Chart.Name "mongodb" }}{{ include "common.names.fullname" . }}{{ end }}'` (parent-chart Secret) |

> **Note:** The template expression evaluates to the Secret name only when rendered **inside the subchart's context** (where `.Chart.Name` equals `"postgresql"` or `"mongodb"`). When rendered in the parent chart's templates, it evaluates to an empty string, so the parent chart's own logic correctly detects "no operator override" and creates the Secret.

**Operator impact:**

- **If you use the bundled datastores with default settings:** No action required. The upgrade will create the kept Secrets. On your next reinstall, the chart will reuse them.
- **If you already provide `postgresql.auth.existingSecret` or `mongodb.auth.existingSecret`:** No change. The chart respects your override and does not create its own Secret.
- **If you want to replace the chart's kept Secret with your own:** Set `postgresql.auth.existingSecret` or `mongodb.auth.existingSecret` to your Secret's name in `values.yaml`. The chart will stop creating its own Secret and reference yours instead.

**Limitations:**

The kept Secret supports only the most common authentication scenarios:
- **PostgreSQL:** `postgres` superuser, a single application user (`midaz`), and replication user. LDAP authentication is **not supported** (the Secret has no `ldap-password` key). If you need LDAP, you must provide your own `existingSecret`.
- **MongoDB:** Root user and replica set key only. Custom application users or metrics users are **not supported**. If you need them, you must provide your own `existingSecret`.

If your configuration requires unsupported features, the chart will fail at render time with a clear error message instructing you to set `auth.existingSecret`.

### 2. MongoDB data volume now persists across uninstall/reinstall

**What changed:**

The MongoDB PersistentVolumeClaim now has `resourcePolicy: keep`, matching the behavior of the PostgreSQL PVCs.

**Why it matters:**

Previously, `helm uninstall` would delete the MongoDB data volume, losing all data. Combined with fix #1 (kept password Secrets), MongoDB data now survives uninstall and is accessible on reinstall.

**Configuration change:**

| Setting | v9.2.5 | v9.2.6 |
|---------|--------|--------|
| `mongodb.persistence.resourcePolicy` | (not set, volume deleted on uninstall) | `keep` |

**Operator impact:**

No action required. Existing volumes are unaffected. New installs and future uninstalls will preserve the MongoDB PVC.

> **Important:** To fully benefit from persistent data across reinstalls, both the PVC **and** the password Secret must survive. This release ensures both do (fixes #1 and #2 together).

## Migration Steps

This is a patch release with no breaking changes. The upgrade is safe and requires no manual intervention.

**Recommended steps:**

1. **Review your `existingSecret` overrides** (if any). If you currently set `postgresql.auth.existingSecret` or `mongodb.auth.existingSecret`, verify that your Secret contains the required keys:
   - PostgreSQL: `postgres-password`, `password`, `replication-password`
   - MongoDB: `mongodb-root-password`, `mongodb-replica-set-key` (if `architecture: replicaset`)

2. **Upgrade the release** using the command below.

3. **Verify the kept Secrets were created** (if you use bundled datastores without `existingSecret` overrides):

   ```bash
   kubectl get secret -n midaz midaz-postgresql -o yaml
   kubectl get secret -n midaz midaz-mongodb -o yaml
   ```

   Confirm the `helm.sh/resource-policy: keep` annotation is present.

4. **(Optional) Test uninstall/reinstall resilience** in a non-production environment:

   ```bash
   # Uninstall the release
   helm uninstall midaz -n midaz
   
   # Verify Secrets and PVCs were kept
   kubectl get secret -n midaz
   kubectl get pvc -n midaz
   
   # Reinstall with the same name
   helm install midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.6 -n midaz
   
   # Verify services reconnect to existing data
   kubectl logs -n midaz deployment/midaz-ledger
   ```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.6 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.6 -n midaz
```
