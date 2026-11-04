# Helm Upgrade from v3.0.5 to v3.0.6

## Topics

- **[Overview](#overview)**
- **[Removed Features](#removed-features)**
  - [1. System Facts Producer Integration](#1-system-facts-producer-integration)
  - [2. Valkey Username Configuration](#2-valkey-username-configuration)
  - [3. Chart Source URL](#3-chart-source-url)
- **[Template Changes](#template-changes)**
  - [1. Pod Label Optimization](#1-pod-label-optimization)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Review System Facts Usage](#step-1-review-system-facts-usage)
  - [Step 2: Remove Valkey Username Override](#step-2-remove-valkey-username-override)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 3.0.6 is a cleanup release that removes the System Facts producer integration and simplifies Valkey authentication configuration. The chart also optimizes pod label rendering to reduce metadata size. **No breaking changes affect operators who have not enabled System Facts** — the upgrade is transparent for standard deployments.

Operators who previously enabled System Facts (`SYSTEM_FACTS_ENABLED=true`) must migrate to an alternative observability solution before upgrading. The Valkey username field is removed (authentication now uses password-only mode), and a redundant chart source URL is cleaned up from metadata.

## Removed Features

### 1. System Facts Producer Integration

**What changed:**  
The System Facts producer integration has been completely removed from the chart. All related configuration fields, template logic, and validation gates have been deleted.

**Removed configuration fields:**

| Field | Location | v3.0.5 Default | Purpose |
|-------|----------|----------------|---------|
| `SYSTEM_FACTS_ENABLED` | `bankTransfer.configmap` | `"false"` | Feature flag to enable System Facts producer |
| `SYSTEM_FACTS_URL` | `bankTransfer.configmap` | `""` | Target URL for fact delivery |
| `SYSTEM_FACTS_REQUIRE_SOURCE_SERVICE` | `bankTransfer.configmap` | `"false"` | Credential rotation flag |
| `SYSTEM_FACTS_INSECURE_HTTP` | `bankTransfer.configmap` | `"false"` | Plaintext HTTP flag (dev-only) |
| `SYSTEM_FACTS_CLIENT_ID` | `bankTransfer.secrets` | `""` | M2M client ID for authentication |
| `SYSTEM_FACTS_CLIENT_SECRET` | `bankTransfer.secrets` | `""` | M2M client secret for authentication |

**Before (v3.0.5):**
```yaml
bankTransfer:
  configmap:
    SYSTEM_FACTS_ENABLED: "true"
    SYSTEM_FACTS_URL: "https://system-facts.example.com"
    SYSTEM_FACTS_REQUIRE_SOURCE_SERVICE: "false"
  secrets:
    SYSTEM_FACTS_CLIENT_ID: "my-client-id"
    SYSTEM_FACTS_CLIENT_SECRET: "my-client-secret"
```

**After (v3.0.6):**
```yaml
# All System Facts fields removed — no replacement
```

**Why it matters:**  
The System Facts integration was an optional observability feature that allowed the plugin to emit structured facts about bank transfer operations to a centralized facts service. Removing it simplifies the chart and reduces maintenance burden. Operators who relied on System Facts must migrate to an alternative observability solution (e.g., application logs, metrics exporters, or custom event forwarding).

**Operational impact:**
- The ConfigMap no longer renders `SYSTEM_FACTS_*` environment variables
- The Secret no longer renders `SYSTEM_FACTS_CLIENT_ID` or `SYSTEM_FACTS_CLIENT_SECRET`
- Template validation gates that enforced System Facts configuration consistency have been removed
- The application will no longer register contracts or emit facts to a System Facts service at boot

**Migration required:**  
Yes, if you currently set `SYSTEM_FACTS_ENABLED=true` — see [Step 1: Review System Facts Usage](#step-1-review-system-facts-usage).

### 2. Valkey Username Configuration

**What changed:**  
The `valkey.auth.username` field has been removed from `values.yaml`. Valkey authentication now uses password-only mode (no username).

**Before (v3.0.5):**
```yaml
valkey:
  auth:
    enabled: true
    password: ""
    username: bank_transfer
```

**After (v3.0.6):**
```yaml
valkey:
  auth:
    enabled: true
    password: ""
```

| Setting | v3.0.5 | v3.0.6 |
|---------|--------|--------|
| `valkey.auth.username` | `bank_transfer` | (removed) |

**Why it matters:**  
Valkey (Redis-compatible) typically uses password-only authentication by default. The `username` field was redundant and not used by the application connection logic. Removing it simplifies the configuration and aligns with standard Valkey deployment patterns.

**Operational impact:**
- The Valkey subchart will no longer receive a `username` override
- The application continues to authenticate using `REDIS_PASSWORD` (no username required)
- Existing deployments with `valkey.auth.username` set will ignore the field after upgrade (Valkey defaults to password-only auth)

**Migration required:**  
No — the change is backward-compatible. If you explicitly override `valkey.auth.username` in your values, remove the override to avoid confusion. See [Step 2: Remove Valkey Username Override](#step-2-remove-valkey-username-override).

### 3. Chart Source URL

**What changed:**  
The redundant GitHub source URL for the plugin application repository has been removed from `Chart.yaml` metadata.

**Before (v3.0.5):**
```yaml
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/plugin-br-bank-transfer
  - https://github.com/LerianStudio/plugin-br-bank-transfer
```

**After (v3.0.6):**
```yaml
sources:
  - https://github.com/LerianStudio/helm/tree/main/charts/plugin-br-bank-transfer
```

**Why it matters:**  
The second URL pointed to the application repository, which is not directly relevant to Helm chart users. The chart repository URL is sufficient for operators. This is a metadata-only change with no operational impact.

**Migration required:**  
No — this is a documentation cleanup with no effect on deployments.

## Template Changes

### 1. Pod Label Optimization

**What changed:**  
The `helm.sh/chart` label is no longer rendered in pod template metadata (Deployment and Job specs). It remains in the Deployment/Job resource metadata itself.

**Before (v3.0.5):**
```yaml
# templates/deployment.yaml
spec:
  template:
    metadata:
      labels:
        helm.sh/chart: plugin-br-bank-transfer-3.0.5
        app.kubernetes.io/name: bank-transfer
        app.kubernetes.io/instance: plugin-br-bank-transfer
        app.kubernetes.io/version: "3.5.0"
        app.kubernetes.io/managed-by: Helm
```

**After (v3.0.6):**
```yaml
# templates/deployment.yaml
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/name: bank-transfer
        app.kubernetes.io/instance: plugin-br-bank-transfer
        app.kubernetes.io/version: "3.5.0"
        app.kubernetes.io/managed-by: Helm
```

**Why it matters:**  
The `helm.sh/chart` label includes the chart version and changes with every chart upgrade. Including it in pod template labels forces pod recreation on every upgrade (even when no pod spec changes). Removing it from pod labels reduces unnecessary pod churn while preserving the label on the Deployment/Job resource for tracking purposes.

**Operational impact:**
- Pod labels will no longer include `helm.sh/chart: plugin-br-bank-transfer-<version>`
- Deployment and Job resources still include the label in their own metadata
- Existing label selectors or monitoring queries that filter on `helm.sh/chart` in pod labels must be updated to query the Deployment/Job resource instead
- The upgrade from v3.0.5 to v3.0.6 will trigger a pod rollout (one-time) due to the label change

**Affected templates:**
- `templates/deployment.yaml` (main application pods)
- `templates/migrations.yaml` (migration Job pods)

**Migration required:**  
No — the change is automatic. If you have monitoring dashboards or alerts that query pod labels for `helm.sh/chart`, update them to query Deployment/Job labels instead:

```bash
# Before (pod label query)
kubectl get pods -l helm.sh/chart=plugin-br-bank-transfer-3.0.5

# After (query Deployment labels, then get pods)
kubectl get deployment -l helm.sh/chart=plugin-br-bank-transfer-3.0.6 -o name | xargs -I {} kubectl get pods -l app.kubernetes.io/name=bank-transfer
```

## Migration Steps

### Step 1: Review System Facts Usage

If you currently have `SYSTEM_FACTS_ENABLED=true` in your values, you must migrate to an alternative observability solution before upgrading.

#### Check if System Facts is enabled

Review your current values:

```bash
helm get values plugin-br-bank-transfer -n midaz-plugins | grep SYSTEM_FACTS_ENABLED
```

If the output shows `SYSTEM_FACTS_ENABLED: "true"`, follow the migration steps below.

#### Option 1: Migrate to application logs

The plugin emits structured logs for all bank transfer operations. Configure log aggregation (e.g., Fluentd, Loki) to capture and query these logs.

**No values changes required** — remove System Facts configuration and rely on existing log output.

#### Option 2: Migrate to custom event forwarding

If you need structured event delivery, implement a custom webhook or message broker integration using the plugin's existing event system.

**Example:** Configure webhook delivery for transfer events:

```yaml
bankTransfer:
  configmap:
    WEBHOOK_ENABLED: "true"
    WEBHOOK_URL: "https://your-event-collector.example.com/events"
  secrets:
    WEBHOOK_SIGNING_SECRET: "<your-webhook-secret>"
```

#### Remove System Facts configuration

After migrating to an alternative solution, remove all System Facts fields from your values:

```yaml
# Remove these fields from your values-override.yaml
bankTransfer:
  configmap:
    # SYSTEM_FACTS_ENABLED: "true"  # DELETE
    # SYSTEM_FACTS_URL: "..."       # DELETE
    # SYSTEM_FACTS_REQUIRE_SOURCE_SERVICE: "..."  # DELETE
  secrets:
    # SYSTEM_FACTS_CLIENT_ID: "..."     # DELETE
    # SYSTEM_FACTS_CLIENT_SECRET: "..." # DELETE
```

> **Warning:** If you upgrade without migrating, you will lose System Facts event delivery. The application will boot normally (System Facts was optional), but no facts will be emitted.

### Step 2: Remove Valkey Username Override

If you explicitly set `valkey.auth.username` in your values, remove it to avoid confusion (the field is ignored in v3.0.6).

**Before (v3.0.5):**
```yaml
valkey:
  auth:
    enabled: true
    password: "my-valkey-password"
    username: bank_transfer
```

**After (v3.0.6):**
```yaml
valkey:
  auth:
    enabled: true
    password: "my-valkey-password"
```

> **Note:** This is optional cleanup — leaving the field in your values will not break the upgrade (it will simply be ignored).

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.0.6
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-bank-transfer oci://registry-1.docker.io/lerianstudio/plugin-br-bank-transfer-helm -n midaz-plugins --version 3.0.6
```
