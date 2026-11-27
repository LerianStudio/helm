<!-- {% raw %} -->
# Helm Upgrade from v0.8.1 to v0.9.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Dedicated API ServiceAccount](#1-dedicated-api-serviceaccount)
- **[Configuration Reference](#configuration-reference)**
  - [API ServiceAccount Configuration](#api-serviceaccount-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review Current ServiceAccount Setup](#step-1-review-current-serviceaccount-setup)
  - [Step 2: Decide on ServiceAccount Strategy](#step-2-decide-on-serviceaccount-strategy)
  - [Step 3: Configure API ServiceAccount (Optional)](#step-3-configure-api-serviceaccount-optional)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a **minor version upgrade** from v0.8.1 to v0.9.0 of the `plugin-br-pix-jd` chart, introducing an optional dedicated ServiceAccount for the API component. This allows operators to grant IAM permissions to the API independently from the worker component, improving security posture in multi-component deployments.

The upgrade maintains full backward compatibility — existing installations will continue using the shared ServiceAccount by default.

| Setting | v0.8.1 | v0.9.0 |
|---------|--------|--------|
| Chart Version | 0.8.1 | 0.9.0 |
| App Version | 1.7.0 | 1.7.0 |
| API ServiceAccount | Shared with worker | Optionally dedicated |

## Features

### 1. Dedicated API ServiceAccount

The chart now supports creating a **separate ServiceAccount** for the API component, allowing operators to segregate IAM permissions between the API and worker.

**Why this matters:**

In environments using IAM role bindings (EKS IRSA, GKE Workload Identity, IAM Roles Anywhere), the API and worker often require different permission scopes:

- **API** — typically needs read-only access to AWS Secrets Manager for multi-tenant credential resolution, plus write access to S3 for QR code storage
- **Worker** — may need broader permissions for reconciliation jobs, MED polling, or refund sweeps

Prior to v0.9.0, both components shared a single ServiceAccount, meaning any permission granted to the API was also granted to the worker. This violated the principle of least privilege.

**How it works:**

The chart introduces a new configuration block `api.serviceAccount` with three modes:

| Mode | Configuration | Behavior |
|------|--------------|----------|
| **Shared** (default) | `api.serviceAccount.create: false` and `api.serviceAccount.name: ""` | API uses the shared ServiceAccount (defined at root level) |
| **Named existing** | `api.serviceAccount.create: false` and `api.serviceAccount.name: "my-api-sa"` | API uses an externally-managed ServiceAccount |
| **Chart-managed** | `api.serviceAccount.create: true` | Chart creates a dedicated ServiceAccount for the API |

**Template changes:**

The chart adds a new helper template `plugin-br-pix-jd.api.serviceAccountName` that resolves the API's ServiceAccount name:

**Before (v0.8.1):**

```yaml
# templates/api/deployment.yaml
spec:
  template:
    spec:
      serviceAccountName: {{ include "plugin-br-pix-jd.serviceAccountName" . }}
```

**After (v0.9.0):**

```yaml
# templates/api/deployment.yaml
spec:
  template:
    spec:
      serviceAccountName: {{ include "plugin-br-pix-jd.api.serviceAccountName" . }}
```

The new helper implements the following resolution logic:

```yaml
# templates/_helpers.tpl
{{- define "plugin-br-pix-jd.api.serviceAccountName" -}}
{{- $sa := .Values.api.serviceAccount -}}
{{- if $sa.create }}
{{- default (include "plugin-br-pix-jd.componentFullname" (dict "root" . "name" "api")) $sa.name }}
{{- else if $sa.name }}
{{- $sa.name }}
{{- else }}
{{- include "plugin-br-pix-jd.serviceAccountName" . }}
{{- end }}
{{- end }}
```

A new template file `templates/api/serviceaccount.yaml` is rendered only when `api.serviceAccount.create: true`:

```yaml
{{- if and .Values.api.enabled .Values.api.serviceAccount.create }}
{{- include "lerian-common.serviceAccount" (dict
      "serviceAccount" (fromYaml (include "plugin-br-pix-jd.withCommonAnnotations" (dict "root" $ "block" .Values.api.serviceAccount)))
      "name" (include "plugin-br-pix-jd.api.serviceAccountName" .)
      "namespace" (include "plugin-br-pix-jd.namespace" $)
      "labels" (include "plugin-br-pix-jd.componentLabels" (dict "root" $ "name" "api"))) }}
{{- end }}
```

**Worker behavior:**

The worker component **always** uses the shared ServiceAccount (defined at root level via `serviceAccount.create` and `serviceAccount.name`). This ensures backward compatibility and maintains the existing permission model for background jobs.

## Configuration Reference

### API ServiceAccount Configuration

```yaml
api:
  # -- Enable the HTTP api component
  enabled: true
  
  # -- A ServiceAccount for the api alone, so a grant to it does not reach the
  # worker. Off and unnamed, the api keeps the shared account above.
  serviceAccount:
    # -- Create a dedicated ServiceAccount for the API
    create: false
    
    # -- Name of the ServiceAccount to use. If not set and create is true,
    # a name is generated using the fullname template with "-api" suffix
    name: ""
    
    # -- Annotations to add to the API ServiceAccount (e.g., IAM role ARN)
    annotations: {}
```

**Field descriptions:**

| Field | Default | Description |
|-------|---------|-------------|
| `api.serviceAccount.create` | `false` | When `true`, the chart creates a dedicated ServiceAccount for the API |
| `api.serviceAccount.name` | `""` | Name of an existing ServiceAccount to use. If empty and `create: true`, generates name as `<release-name>-plugin-br-pix-jd-api` |
| `api.serviceAccount.annotations` | `{}` | Annotations applied to the API ServiceAccount (e.g., `eks.amazonaws.com/role-arn` for IRSA) |

## Migration Steps

### Step 1: Review Current ServiceAccount Setup

Check your current ServiceAccount configuration:

```bash
helm get values plugin-br-pix-jd -n midaz-plugins
```

Look for the root-level `serviceAccount` block:

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/plugin-pix-combined
```

This ServiceAccount is currently used by **both** the API and worker.

### Step 2: Decide on ServiceAccount Strategy

Choose one of the following strategies based on your security requirements:

#### Option 1: Keep Existing Shared ServiceAccount (No Action Required)

If your API and worker require the same IAM permissions, or you are not using IAM role bindings, **no changes are needed**. The chart defaults to the shared ServiceAccount model.

**Configuration:**

```yaml
# No changes needed — api.serviceAccount defaults to:
api:
  serviceAccount:
    create: false
    name: ""
```

The API will continue using the shared ServiceAccount defined at root level.

#### Option 2: Create Dedicated API ServiceAccount

If you need to segregate permissions between the API and worker, enable the dedicated API ServiceAccount.

**Use case example:**

- **API** needs read-only access to AWS Secrets Manager for multi-tenant credential resolution
- **Worker** needs write access to S3 for refund-park sweeps and MED polling

**Configuration:**

```yaml
# Root-level ServiceAccount (used by worker)
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/plugin-pix-worker

# Dedicated API ServiceAccount
api:
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/plugin-pix-api
```

> **Important:** When using EKS IRSA, you must create **two separate IAM roles** with different trust policies and permission boundaries. The API role should have minimal permissions (e.g., `secretsmanager:GetSecretValue` on specific secret ARNs), while the worker role can have broader permissions for background jobs.

#### Option 3: Use Existing External ServiceAccount for API

If you manage ServiceAccounts outside Helm (e.g., via Terraform or a separate Helm chart), reference the existing ServiceAccount by name.

**Configuration:**

```yaml
api:
  serviceAccount:
    create: false
    name: my-existing-api-serviceaccount
```

> **Note:** The chart will **not** create or manage this ServiceAccount. Ensure it exists in the target namespace before upgrading.

### Step 3: Configure API ServiceAccount (Optional)

If you chose Option 2 or Option 3 above, update your `values.yaml`:

**Example for EKS IRSA with dedicated API role:**

```yaml
# values.yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/plugin-pix-worker

api:
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/plugin-pix-api-readonly
```

**Example for GKE Workload Identity:**

```yaml
serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: plugin-pix-worker@project-id.iam.gserviceaccount.com

api:
  serviceAccount:
    create: true
    annotations:
      iam.gke.io/gcp-service-account: plugin-pix-api@project-id.iam.gserviceaccount.com
```

**Example for IAM Roles Anywhere (non-EKS):**

```yaml
# Root ServiceAccount used by worker
serviceAccount:
  create: true

# Dedicated API ServiceAccount
api:
  serviceAccount:
    create: true
    name: plugin-pix-api

# IAM Roles Anywhere configuration (applies to both components via sidecar)
aws:
  rolesAnywhere:
    enabled: true
    trustAnchorArn: arn:aws:rolesanywhere:us-east-2:123456789012:trust-anchor/abc123
    profileArn: arn:aws:rolesanywhere:us-east-2:123456789012:profile/def456
    roleArn: arn:aws:iam::123456789012:role/plugin-pix-api
    certificateSecretName: plugin-pix-api-iam-tls
```

> **Note:** When using IAM Roles Anywhere, the `roleArn` in `aws.rolesAnywhere` applies to **both** the API and worker sidecars. To segregate permissions, you must deploy separate Helm releases with different `roleArn` values, or manage the credential-helper sidecar outside the chart.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.9.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://ghcr.io/lerianstudio/plugin-br-pix-jd-helm -n midaz-plugins --version 0.9.0
```
<!-- {% endraw %} -->
