# Helm Upgrade from v4.3.1 to v4.3.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Bundled RabbitMQ credential now explicitly documented and guarded](#1-bundled-rabbitmq-credential-now-explicitly-documented-and-guarded)
  - [2. Bundled SeaweedFS now schedules on arm64 nodes](#2-bundled-seaweedfs-now-schedules-on-arm64-nodes)
  - [3. CRM datasource now supports inline TLS CA bundles](#3-crm-datasource-now-supports-inline-tls-ca-bundles)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that fixes the bundled RabbitMQ broker's credential handling, enables the bundled SeaweedFS object storage to schedule on arm64 nodes (e.g., Apple Silicon minikube), and adds support for inline TLS CA bundles for the CRM datasource (e.g., AWS DocumentDB). The application version is bumped to `3.0.2`.

| Field | v4.3.1 | v4.3.2 |
|-------|--------|--------|
| Chart version | `4.3.1` | `4.3.2` |
| App version | `3.0.1` | `3.0.2` |
| Manager image tag | `3.0.1` | `3.0.2` |
| Worker image tag | `3.0.1` | `3.0.2` |

## Fixes

### 1. Bundled RabbitMQ credential now explicitly documented and guarded

The bundled RabbitMQ broker (enabled via `rabbitmq.enabled=true`) takes its only login from the operator's `secrets.RABBITMQ_DEFAULT_PASS`, and the render refuses an empty password. Prior releases left `secrets.RABBITMQ_DEFAULT_PASS` empty by default, which caused the bundled broker to fail at boot (the user was declared in the imported definitions file with a password hash, but the application Secret had no matching plaintext password for the workloads to authenticate with).

**Before (v4.3.1):**

The bundled broker imported a definitions file that declared a `reporter` user with a salted password hash, but `secrets.RABBITMQ_DEFAULT_PASS` was empty. The manager and worker pods attempted to authenticate with an empty password, which the broker rejected (403). The TCP startup probe did not catch this, so the pods appeared healthy but could not connect to the broker.

**After:**

The broker imports the operator's password with its definitions at every boot, so the workloads and the broker share one credential and there is no password hash to keep in step. See the README's "Bundled broker login" for the passwords the render refuses, the characters the apps accept, and the broker restart a password change needs.

**Rendered values:**

```yaml
secrets:
  RABBITMQ_DEFAULT_USER: reporter
  RABBITMQ_DEFAULT_PASS: <your-rabbitmq-password>

rabbitmq:
  enabled: true
```

> **Important:** The render-time guard also refuses `manager.useExistingSecret` or `worker.useExistingSecret` when `rabbitmq.enabled=true`. A component external Secret can carry its own `RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` that the bundled broker never learns (the worker path is invisible to the manager-name guard), so that workload would authenticate with a credential the broker rejects. Use an external broker with `useExistingSecret`, or drop `useExistingSecret` so the chart single-sources the bundled broker credential.

### 2. Bundled SeaweedFS now schedules on arm64 nodes

The bundled SeaweedFS subchart hard-pinned `nodeSelector: kubernetes.io/arch: amd64` on every component (master, volume, filer, s3), which caused the pods to stay Pending forever on arm64 nodes (e.g., Apple Silicon minikube) and prevented object-storage readiness from coming up. This release unpins the selector (sets it to an empty string, which causes the subchart's `{{ if .nodeSelector }}` conditional to drop the block) so the bundled storage schedules on any architecture.

| Component | v4.3.1 | v4.3.2 |
|-----------|--------|--------|
| `seaweedfs.master.nodeSelector` | `kubernetes.io/arch: amd64` (hardcoded in subchart) | `""` (unpinned) |
| `seaweedfs.volume.nodeSelector` | `kubernetes.io/arch: amd64` (hardcoded in subchart) | `""` (unpinned) |
| `seaweedfs.filer.nodeSelector` | `kubernetes.io/arch: amd64` (hardcoded in subchart) | `""` (unpinned) |
| `seaweedfs.s3.nodeSelector` | `kubernetes.io/arch: amd64` (hardcoded in subchart) | `""` (unpinned) |

**Before (v4.3.1):**

On an arm64 cluster (e.g., `minikube start --driver=docker` on Apple Silicon), the SeaweedFS pods stayed Pending:

```bash
kubectl get pods -n reporter
```

```
NAME                              READY   STATUS    RESTARTS   AGE
reporter-seaweedfs-master-0       0/1     Pending   0          5m
reporter-seaweedfs-volume-0       0/1     Pending   0          5m
reporter-seaweedfs-filer-0        0/1     Pending   0          5m
reporter-seaweedfs-s3-0           0/1     Pending   0          5m
```

```bash
kubectl describe pod reporter-seaweedfs-master-0 -n reporter
```

```
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  5m    default-scheduler  0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector.
```

**After:**

The bundled SeaweedFS components schedule on any architecture. amd64 clusters are unaffected (no selector still matches amd64 nodes). To re-pin to a specific architecture, set a real selector per component:

```yaml
seaweedfs:
  master:
    nodeSelector: |
      kubernetes.io/arch: amd64
  volume:
    nodeSelector: |
      kubernetes.io/arch: amd64
  filer:
    nodeSelector: |
      kubernetes.io/arch: amd64
  s3:
    nodeSelector: |
      kubernetes.io/arch: amd64
```

> **Note:** The subchart expects a multi-line STRING for `nodeSelector`, not a map. Use the `|` block scalar syntax as shown above.

### 3. CRM datasource now supports inline TLS CA bundles

The CRM datasource (an optional MongoDB source for customer relationship management data) now accepts an inline Base64-encoded CA bundle via `DATASOURCE_CRM_SSLCA_BASE64`, in addition to the legacy file-path approach (`DATASOURCE_CRM_SSLROOTCERT`). This enables TLS connections to managed MongoDB services (e.g., AWS DocumentDB) without mounting a volume — the trust anchor is passed as an environment variable, which works with any secret manager. Requires reporter application version `3.0.2` or later.

| Setting | v4.3.1 | v4.3.2 |
|---------|--------|--------|
| `common.configmap.DATASOURCE_CRM_SSLCA_BASE64` | not supported | supported (Base64 of PEM CA bundle) |
| `common.configmap.DATASOURCE_CRM_SSLROOTCERT` | supported (file path) | supported (mutually exclusive with `SSLCA_BASE64`) |

**Example configuration for AWS DocumentDB (v4.3.2):**

```yaml
common:
  configmap:
    DATASOURCE_CRM_CONFIG_NAME: "plugin_crm"
    DATASOURCE_CRM_TYPE: "mongodb"
    DATASOURCE_CRM_HOST: "shared-docdb.cluster-xxxx.us-east-1.docdb.amazonaws.com"
    DATASOURCE_CRM_PORT: "27017"
    DATASOURCE_CRM_DATABASE: "crm"
    DATASOURCE_CRM_USER: "reporter"
    DATASOURCE_CRM_MIDAZ_ORGANIZATION_ID: "<organization-id>"
    DATASOURCE_CRM_SSLMODE: "require"
    DATASOURCE_CRM_SSLCA_BASE64: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t..."

secrets:
  DATASOURCE_CRM_PASSWORD: "your-crm-password"
```

> **Important:** Two hard requirements for `DATASOURCE_CRM_SSLCA_BASE64`:
> 
> 1. **SCOPE THE BUNDLE.** Use the per-region / per-cluster CA, NOT the full AWS global bundle. The global `rds-combined/global-bundle.pem` is ~108 certificates (~220 KB Base64); as a single environment variable it exceeds the Linux per-arg env limit (`MAX_ARG_STRLEN`, 128 KB) and the container fails to exec ("argument list too long") — the pod never starts. The regional bundle (e.g., `https://truststore.pki.rds.amazonaws.com/us-east-1/us-east-1-bundle.pem`, a few KB) still validates and is what you want. Custom PKI: ship only the issuing chain.
> 
> 2. **SINGLE LINE, NO NEWLINES.** The app decodes with strict Base64 and rejects embedded newlines. Produce it with: `base64 -w0 ca.pem` (macOS: `base64 ca.pem | tr -d '\n'`). In this YAML use a plain double-quoted scalar — do NOT use a block scalar (`|` / `>`), which reintroduces newlines.

**Fetch the regional AWS RDS/DocumentDB CA and produce the value:**

```bash
REGION=us-east-1   # e.g. the region in the DATASOURCE_CRM_HOST endpoint
curl -fsSLO "https://truststore.pki.rds.amazonaws.com/${REGION}/${REGION}-bundle.pem"
base64 -w0 "${REGION}-bundle.pem"                 # Linux — paste the output as the value
base64 "${REGION}-bundle.pem" | tr -d '\n'        # macOS equivalent
```

**Sanity-check it validates before deploying:**

```bash
mongosh "mongodb://<DATASOURCE_CRM_HOST>:27017/?tls=true&tlsCAFile=${REGION}-bundle.pem&retryWrites=false" \
  --username '<user>' --password '<pass>' --authenticationDatabase admin --quiet --eval 'db.runCommand({ping:1})'
```

> **Note:** `DATASOURCE_CRM_SSLCA_BASE64` and `DATASOURCE_CRM_SSLROOTCERT` are mutually exclusive. Set EITHER the inline CA bundle (Base64) OR the file path, never both. The same pattern applies to any other `DATASOURCE_<NAME>_SSLCA_BASE64`.

## Configuration Changes

No `values.yaml` keys were added, removed, or renamed. The changes are:

1. `secrets.RABBITMQ_DEFAULT_PASS` is required with the bundled broker: it is the broker's only login.
2. `seaweedfs.master.nodeSelector`, `seaweedfs.volume.nodeSelector`, `seaweedfs.filer.nodeSelector`, and `seaweedfs.s3.nodeSelector` now default to `""` (unpinned, was hardcoded `kubernetes.io/arch: amd64` in the subchart).
3. `common.configmap` now accepts `DATASOURCE_CRM_SSLCA_BASE64` (inline Base64 CA bundle) as an alternative to `DATASOURCE_CRM_SSLROOTCERT` (file path).

| Setting | v4.3.1 | v4.3.2 | Notes |
|---------|--------|--------|-------|
| `secrets.RABBITMQ_DEFAULT_PASS` | `""` | your password (required) | The bundled broker's only login; the render refuses an empty one |
| `seaweedfs.master.nodeSelector` | `kubernetes.io/arch: amd64` (subchart default) | `""` | Unpinned; set a real selector to re-pin |
| `seaweedfs.volume.nodeSelector` | `kubernetes.io/arch: amd64` (subchart default) | `""` | Unpinned; set a real selector to re-pin |
| `seaweedfs.filer.nodeSelector` | `kubernetes.io/arch: amd64` (subchart default) | `""` | Unpinned; set a real selector to re-pin |
| `seaweedfs.s3.nodeSelector` | `kubernetes.io/arch: amd64` (subchart default) | `""` | Unpinned; set a real selector to re-pin |
| `common.configmap.DATASOURCE_CRM_SSLCA_BASE64` | not supported | supported | Base64 of PEM CA bundle; mutually exclusive with `SSLROOTCERT` |

## Migration Steps

This upgrade requires no mandatory values changes for most deployments. The Helm upgrade will roll the manager and worker deployments to the new image tags (`3.0.2`).

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

2. **If you are using the bundled RabbitMQ broker (`rabbitmq.enabled=true`):**
   - Set `secrets.RABBITMQ_DEFAULT_PASS` to your own password; the render refuses an empty one.

3. **If you are using the bundled SeaweedFS object storage on an arm64 cluster (e.g., Apple Silicon minikube):**
   - The upgrade will unpin the architecture selector and allow the pods to schedule. No action required.

4. **If you are configuring a CRM datasource with TLS (e.g., AWS DocumentDB):**
   - Optionally migrate from the file-path approach (`DATASOURCE_CRM_SSLROOTCERT`) to the inline CA bundle approach (`DATASOURCE_CRM_SSLCA_BASE64`). See [Fix #3](#3-crm-datasource-now-supports-inline-tls-ca-bundles) for instructions.

5. Run the upgrade command during a maintenance window.

6. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n reporter
```

7. Check manager and worker logs:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-worker --tail=50
```

8. If using the bundled RabbitMQ broker, verify the workloads can authenticate:

```bash
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-manager --tail=50 | grep -i rabbitmq
kubectl logs -n reporter -l app.kubernetes.io/name=reporter-worker --tail=50 | grep -i rabbitmq
```

> **Note:** The upgrade triggers a rolling restart of both the manager and worker deployments. If you are using the bundled RabbitMQ broker without `secrets.RABBITMQ_DEFAULT_PASS`, the render will fail before any resources are applied.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.2 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.2 -n reporter
```
