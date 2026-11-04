<!-- {% raw %} -->
# Helm Upgrade from v5.3.1 to v5.3.2

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Chart metadata updated for new repository location](#1-chart-metadata-updated-for-new-repository-location)
  - [2. Extra volumes and volume mounts support added](#2-extra-volumes-and-volume-mounts-support-added)
  - [3. MongoDB TLS verification improved for DocumentDB](#3-mongodb-tls-verification-improved-for-documentdb)
  - [4. Pod label and annotation checksums corrected](#4-pod-label-and-annotation-checksums-corrected)
  - [5. License key error message clarified](#5-license-key-error-message-clarified)
  - [6. RabbitMQ bootstrap TLS verification comment updated](#6-rabbitmq-bootstrap-tls-verification-comment-updated)
  - [7. Valkey documentation reference removed](#7-valkey-documentation-reference-removed)
  - [8. AWS Roles Anywhere comment simplified](#8-aws-roles-anywhere-comment-simplified)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that updates chart metadata to reflect the new repository location, adds support for extra volumes and volume mounts on manager and worker components, improves MongoDB TLS verification for AWS DocumentDB, and fixes several template rendering issues. No breaking changes are introduced.

| Field | v5.3.1 | v5.3.2 |
|-------|--------|--------|
| Chart version | `5.3.1` | `5.3.2` |
| App version | `4.8.0` | `4.8.0` |

## Fixes

### 1. Chart metadata updated for new repository location

The chart's `home` and `sources` URLs have been updated to point to the new `LerianStudio/helm` repository instead of the application repository. The chart description has also been expanded to clarify what components are deployed.

| Field | v5.3.1 | v5.3.2 |
|-------|--------|--------|
| `description` | `A Helm chart for deploying Golang applications` | `Installs Lerian Reporter, the manager API and the report-generation worker, with optional MongoDB, RabbitMQ, Valkey and SeaweedFS` |
| `home` | `https://github.com/LerianStudio/reporter/tree/main/deploy/charts/reporter` | `https://github.com/LerianStudio/helm/tree/main/charts/reporter` |
| `sources[0]` | `https://github.com/LerianStudio/reporter/tree/main/deploy/charts/reporter` | `https://github.com/LerianStudio/helm/tree/main/charts/reporter` |
| `sources[1]` | `https://github.com/LerianStudio/reporter` | removed |

> **Note:** This change does not affect chart functionality. The OCI registry location remains unchanged.

### 2. Extra volumes and volume mounts support added

Both `manager` and `worker` components now support `extraVolumes` and `extraVolumeMounts` fields in `values.yaml`. This allows operators to mount additional volumes (e.g., ConfigMaps, Secrets, or PersistentVolumeClaims) into the manager and worker pods without modifying chart templates.

**New fields added:**

| Component | Field | Default | Description |
|-----------|-------|---------|-------------|
| `manager` | `extraVolumes` | `[]` | Extra pod volumes, e.g. a ConfigMap containing a regulatory catalog tree |
| `manager` | `extraVolumeMounts` | `[]` | Extra container volume mounts, e.g. mounting the catalog tree at `REGULATORY_CATALOG_DIR` |
| `worker` | `extraVolumes` | `[]` | Extra pod volumes, e.g. a ConfigMap containing a regulatory catalog tree |
| `worker` | `extraVolumeMounts` | `[]` | Extra container volume mounts, e.g. mounting the catalog tree at `REGULATORY_CATALOG_DIR` |

**Example configuration:**

```yaml
manager:
  extraVolumes:
    - name: regulatory-catalog
      configMap:
        name: reporter-regulatory-catalog
  extraVolumeMounts:
    - name: regulatory-catalog
      mountPath: /etc/reporter/catalog
      readOnly: true
  extraEnvVars:
    REGULATORY_CATALOG_DIR: /etc/reporter/catalog

worker:
  extraVolumes:
    - name: regulatory-catalog
      configMap:
        name: reporter-regulatory-catalog
  extraVolumeMounts:
    - name: regulatory-catalog
      mountPath: /etc/reporter/catalog
      readOnly: true
  extraEnvVars:
    REGULATORY_CATALOG_DIR: /etc/reporter/catalog
```

> **Note:** The `extraVolumes` and `extraVolumeMounts` fields are rendered directly into the Deployment and ScaledJob templates. Ensure volume names are unique and do not conflict with existing volumes (e.g., `tmp` for worker, AWS Roles Anywhere volumes).

**Rendered template changes:**

**Before (v5.3.1):**

```yaml
# manager Deployment
spec:
  template:
    spec:
      containers:
        - name: manager
          # ... other fields
      # No volumes block unless AWS Roles Anywhere is enabled
```

**After (v5.3.2):**

```yaml
# manager Deployment
spec:
  template:
    spec:
      containers:
        - name: manager
          volumeMounts:
            - name: regulatory-catalog
              mountPath: /etc/reporter/catalog
              readOnly: true
      volumes:
        - name: regulatory-catalog
          configMap:
            name: reporter-regulatory-catalog
```

**Before (v5.3.1):**

```yaml
# worker Deployment
spec:
  template:
    spec:
      containers:
        - name: worker
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

**After (v5.3.2):**

```yaml
# worker Deployment
spec:
  template:
    spec:
      containers:
        - name: worker
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: regulatory-catalog
              mountPath: /etc/reporter/catalog
              readOnly: true
      volumes:
        - name: tmp
          emptyDir: {}
        - name: regulatory-catalog
          configMap:
            name: reporter-regulatory-catalog
```

### 3. MongoDB TLS verification improved for DocumentDB

The chart now automatically removes `tlsInsecure=true` from the `MONGO_PARAMETERS` environment variable when using AWS DocumentDB with the shared cloud preset and the application version is 4.7.0 or newer. Starting with app version 4.7.0 (lib-commons 7.20.0), the application bundles the AWS RDS CA certificate and can verify DocumentDB connections without disabling TLS verification.

**Behavior changes:**

| Scenario | v5.3.1 | v5.3.2 |
|----------|--------|--------|
| DocumentDB + cloud preset + app >= 4.7.0 | `MONGO_PARAMETERS` includes `tlsInsecure=true` | `MONGO_PARAMETERS` has `tlsInsecure=true` removed |
| DocumentDB + cloud preset + app < 4.7.0 | `MONGO_PARAMETERS` includes `tlsInsecure=true` | `MONGO_PARAMETERS` includes `tlsInsecure=true` (unchanged) |
| DocumentDB + custom `MONGO_PARAMETERS` | Custom value unchanged | Custom value unchanged |
| Bundled MongoDB or other external MongoDB | Not affected | Not affected |

**Example rendered environment variable:**

**Before (v5.3.1) with cloud preset and app 4.8.0:**

```yaml
env:
  - name: MONGO_PARAMETERS
    value: "maxIdleTimeMS=60000&tlsInsecure=true&tls=true"
```

**After (v5.3.2) with cloud preset and app 4.8.0:**

```yaml
env:
  - name: MONGO_PARAMETERS
    value: "maxIdleTimeMS=60000&tls=true"
```

> **Note:** This change only applies when the cloud preset's default `MONGO_PARAMETERS` value is used. If you have explicitly set `manager.configmap.MONGO_PARAMETERS` or `worker.configmap.MONGO_PARAMETERS` in your values, those overrides are not modified.

> **Important:** If you are using a pinned image tag older than 4.7.0 (e.g., `manager.image.tag: "4.6.0"`), the chart will preserve `tlsInsecure=true` in the cloud preset to maintain compatibility. Floating tags (e.g., `latest`) or digest references are treated as new versions and will have `tlsInsecure=true` removed.

### 4. Pod label and annotation checksums corrected

The manager and worker Deployment templates now correctly compute checksums for the `checksum/secret` and `checksum/config` annotations. Previously, the checksums included the entire rendered YAML document (including metadata); now they hash only the `data` field of the Secret and ConfigMap, ensuring that pod restarts are triggered only when actual configuration content changes.

**Before (v5.3.1):**

```yaml
annotations:
  checksum/secret: {{ include (print $.Template.BasePath "/manager/secrets.yaml") . | sha256sum }}
  checksum/config: {{ include (print $.Template.BasePath "/manager/configmap.yaml") . | sha256sum }}
```

**After (v5.3.2):**

```yaml
annotations:
  checksum/secret: {{ (include (print $.Template.BasePath "/manager/secrets.yaml") . | fromYaml).data | toYaml | sha256sum }}
  checksum/config: {{ (include (print $.Template.BasePath "/manager/configmap.yaml") . | fromYaml).data | toYaml | sha256sum }}
```

> **Note:** This fix prevents unnecessary pod restarts when only Secret or ConfigMap metadata (e.g., labels, annotations) changes. Pods will still restart when the actual secret or config data changes.

The manager and worker Deployment templates also now include the full set of standard labels (`app.kubernetes.io/version` and `app.kubernetes.io/managed-by`) in the pod template metadata, not just selector labels. This aligns with Kubernetes labeling best practices.

**Before (v5.3.1):**

```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "plugin-manager.labels" (dict "context" . "name" .Values.manager.name ) | nindent 8 }}
```

**After (v5.3.2):**

```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "plugin-manager.selectorLabels" (dict "context" . "name" .Values.manager.name) | nindent 8 }}
        app.kubernetes.io/version: {{ include "plugin.version" . }}
        app.kubernetes.io/managed-by: {{ .Release.Service }}
```

### 5. License key error message clarified

The error message displayed when `secrets.LICENSE_KEY` is missing for app versions >= 4.6.0 has been updated to clarify that operators should set `manager.useExistingSecret=true` and `manager.existingSecretName` (or `worker.useExistingSecret=true` and `worker.existingSecretName`) when using an existing Secret, rather than the removed `secrets.ORGANIZATION_IDS` field.

**Before (v5.3.1):**

```
ERROR: secrets.LICENSE_KEY is REQUIRED for reporter app >= 4.6.0 (manager.image.tag is "4.8.0").
   The manager AND the worker refuse to boot without a license.
   Set secrets.LICENSE_KEY (and secrets.ORGANIZATION_IDS for a per-organization license),
   or point manager.useExistingSecret at a Secret that carries them.
   See charts/reporter/docs/UPGRADE-5.1.md.
```

**After (v5.3.2):**

```
ERROR: secrets.LICENSE_KEY is REQUIRED for reporter app >= 4.6.0 (manager.image.tag is "4.8.0").
   The manager AND the worker refuse to boot without a license.
   Set secrets.LICENSE_KEY,
   or set manager.useExistingSecret=true and manager.existingSecretName to a Secret that carries them.
   See charts/reporter/docs/UPGRADE-5.1.md.
```

> **Note:** This is a documentation-only change in the error message. The license key validation logic is unchanged.

### 6. RabbitMQ bootstrap TLS verification comment updated

The comment in the RabbitMQ bootstrap Job template that explains the `RABBITMQ_SKIP_TLS_VERIFY` environment variable has been updated to remove a stale reference to the `plugin-bc-correios` chart.

**Before (v5.3.1):**

```yaml
# Pattern and env-var name follow
# charts/plugin-br-bank-transfer/templates/bootstrap-rabbitmq.yaml:71-76 (same block
# at charts/plugin-bc-correios/templates/bootstrap-rabbitmq.yaml:66-71) — the base-URL
# block below was already copied from that sibling; this is the block that sits
# directly above it there and was left behind.
```

**After (v5.3.2):**

```yaml
# Pattern and env-var name follow
# charts/plugin-br-bank-transfer/templates/bootstrap-rabbitmq.yaml:71-76 — the base-URL
# block below was already copied from that sibling; this is the block that sits
# directly above it there and was left behind.
```

> **Note:** This is a comment-only change and does not affect chart behavior.

### 7. Valkey documentation reference removed

The comment above the `valkey` section in `values.yaml` that linked to Midaz documentation has been removed, as it was not relevant to the Reporter chart.

**Before (v5.3.1):**

```yaml
valkey:
  # Redis is used to handle scenarios where real-time performance and fast data retrieval are essential.
  # This component is responsible for providing an in-memory data store
  # For more details, refer to the documentation:
  # https://docs.lerian.studio/docs/midaz-components#why-redis
  enabled: true
```

**After (v5.3.2):**

```yaml
valkey:
  # Redis is used to handle scenarios where real-time performance and fast data retrieval are essential.
  # This component is responsible for providing an in-memory data store
  enabled: true
```

> **Note:** This is a comment-only change and does not affect chart behavior.

### 8. AWS Roles Anywhere comment simplified

The comment for the `aws.rolesAnywhere` section in `values.yaml` has been simplified to remove the example cluster names.

**Before (v5.3.1):**

```yaml
# -- AWS Authentication - IAM Roles Anywhere for non-AWS clusters (e.g. Clotilde/Proxmox)
aws:
  rolesAnywhere:
    enabled: false
```

**After (v5.3.2):**

```yaml
# -- AWS Authentication - IAM Roles Anywhere for non-AWS clusters
aws:
  rolesAnywhere:
    enabled: false
```

> **Note:** This is a comment-only change and does not affect chart behavior.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.3.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm -n reporter --version 5.3.2
```
<!-- {% endraw %} -->
