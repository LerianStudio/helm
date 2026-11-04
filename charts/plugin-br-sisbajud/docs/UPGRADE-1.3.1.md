<!-- {% raw %} -->
# Helm Upgrade from v1.3.0 to v1.3.1

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.3.0** to **1.3.1**. This is a patch release that includes documentation clarifications, pod label improvements, and checksum calculation refinements.

## Table of Contents

- **[Overview](#overview)**
- **[Changes](#changes)**
  - [1. Documentation Updates](#1-documentation-updates)
  - [2. Pod Label Structure](#2-pod-label-structure)
  - [3. Checksum Calculation Improvements](#3-checksum-calculation-improvements)
- **[Migration Impact](#migration-impact)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.3.1 is a patch release that improves the chart's operational characteristics without introducing breaking changes or requiring configuration updates.

**What changed:**

| Area | Change |
|------|--------|
| Chart metadata | Removed obsolete source URL from `Chart.yaml` |
| Documentation | Clarified executor sweep behavior and removed outdated references |
| Pod labels | Refined label structure to use `selectorLabels` + version/management labels |
| Checksums | Improved checksum calculation to hash only the data/stringData content |

**Migration impact:**

- **No configuration changes required** — all existing `values.yaml` configurations remain valid
- **Pod restart triggered** — label changes will cause pods to be recreated during upgrade
- **No functional changes** — application behavior is identical to v1.3.0

> **Note:** This release does not modify the application image version (`Chart.appVersion` remains unchanged).

## Changes

### 1. Documentation Updates

The chart includes several documentation clarifications that improve operator understanding without changing behavior.

#### Executor Order Sweep Description

The `EXECUTOR_ORDER_SWEEP_ENABLED` flag description has been clarified to better explain what the sweep does.

**Before (v1.3.0):**

```yaml
sisbajud:
  executor:
    # -- EXECUTOR_ORDER_SWEEP_ENABLED: the execution_order sweep that closes
    #    stale orders (true | false; app default false).
    orderSweepEnabled: "false"
```

**After (v1.3.1):**

```yaml
sisbajud:
  executor:
    # -- EXECUTOR_ORDER_SWEEP_ENABLED: the sweep that closes done
    #    execution_order revisions (true | false; app default false).
    orderSweepEnabled: "false"
```

**What this means:**

The sweep closes **done** execution_order revisions (completed orders), not "stale" orders. This clarification does not change the flag's behavior — it only corrects the documentation to match what the application actually does.

#### Direct Channel Purge Documentation

The purge eligibility comment has been simplified by removing a reference to an external runbook.

**Before (v1.3.0):**

```yaml
sisbajud:
  executor:
    direct:
      # -- EXECUTOR_DIRECT_PURGE_ELIGIBLE_ALARM_AFTER: alarm after this duration
      #    if purge-eligible rows exist (Go duration > 0; app default 168h = 1 week).
      #    No automatic purge: a person decides, through the audited erase
      #    (purge preview + erase by order). A BLOCK order is kept at least one
      #    CALENDAR year after its first ledger effect; an ACTIVE permanent block
      #    is never eligible (runbook direct-channel-operations.md § 10).
      purgeEligibleAlarmAfter: "168h"
```

**After (v1.3.1):**

```yaml
sisbajud:
  executor:
    direct:
      # -- EXECUTOR_DIRECT_PURGE_ELIGIBLE_ALARM_AFTER: alarm after this duration
      #    if purge-eligible rows exist (Go duration > 0; app default 168h = 1 week).
      #    No automatic purge: a person decides, through the audited erase
      #    (purge preview + erase by order). A BLOCK order is kept at least one
      #    CALENDAR year after its first ledger effect; an ACTIVE permanent block
      #    is never eligible.
      purgeEligibleAlarmAfter: "168h"
```

**What this means:**

The purge eligibility rules remain the same — only the reference to an external runbook section has been removed from the comment.

#### Template Comment Updates

Internal template comments have been updated to remove obsolete references:

- Removed "DR-07" reference from executor mode documentation (direct-only mode)
- Removed "DR-03/DR-04" references from image tag validation comments
- Removed "DR-04, rule B'" reference from image tag gate comments

These are internal documentation changes that do not affect chart behavior or operator configuration.

#### NOTES.txt Simplification

The post-install notes have been simplified by removing a line about the `/readyz` endpoint's object-store probe.

**Before (v1.3.0):**

```
Ledger routing and credentials are per institution (institution config API), not chart values.
/readyz also reports the object-store (SeaweedFS/S3) probe the app wires in every mode; see the chart README.
```

**After (v1.3.1):**

```
Ledger routing and credentials are per institution (institution config API), not chart values.
```

**What this means:**

The `/readyz` endpoint still includes the object-store probe — this change only removes the note from the post-install output. Refer to the chart README for complete health check documentation.

### 2. Pod Label Structure

The Deployment template now uses a more precise label structure that separates selector labels from metadata labels.

**Before (v1.3.0):**

```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "plugin-br-sisbajud.labels" (dict "context" $ "component" "sisbajud") | nindent 8 }}
```

**After (v1.3.1):**

```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "plugin-br-sisbajud.selectorLabels" (dict "context" $ "component" "sisbajud") | nindent 8 }}
        app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
        app.kubernetes.io/managed-by: {{ .Release.Service }}
        app.kubernetes.io/part-of: {{ include "plugin-br-sisbajud.name" . }}
```

**What this means:**

The pod template now explicitly includes:

- **Selector labels** (`app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/component`) — these are immutable and used by the Service selector
- **Version label** (`app.kubernetes.io/version`) — tracks the application version
- **Management label** (`app.kubernetes.io/managed-by`) — identifies Helm as the manager
- **Part-of label** (`app.kubernetes.io/part-of`) — groups resources by chart name

**Operational impact:**

- **Pod restart required** — label changes trigger a rolling update of the Deployment
- **No service disruption** — the Service selector uses only the immutable selector labels, so traffic routing is unaffected
- **Improved observability** — the explicit version label makes it easier to identify which application version is running

> **Note:** The label change is cosmetic and does not affect pod behavior, networking, or configuration. The upgrade will perform a standard rolling update.

### 3. Checksum Calculation Improvements

The Deployment template now calculates checksums more precisely by hashing only the actual data content of ConfigMaps and Secrets, rather than the entire rendered YAML.

**Before (v1.3.0):**

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- if not $s.useExistingSecret }}
        checksum/secret: {{ include (print $.Template.BasePath "/secrets.yaml") . | sha256sum }}
        {{- end }}
```

**After (v1.3.1):**

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/config: {{ (include (print $.Template.BasePath "/configmap.yaml") . | fromYaml).data | toYaml | sha256sum }}
        {{- if not $s.useExistingSecret }}
        checksum/secret: {{ (include (print $.Template.BasePath "/secrets.yaml") . | fromYaml).stringData | toYaml | sha256sum }}
        {{- end }}
```

**What this means:**

The checksum annotations now hash only the `data` field of the ConfigMap and the `stringData` field of the Secret, excluding metadata like labels, annotations, and resource names.

**Why this matters:**

- **More stable checksums** — changes to ConfigMap/Secret metadata (labels, annotations) no longer trigger pod restarts
- **Accurate change detection** — pods restart only when the actual configuration data changes, not when unrelated metadata changes
- **Consistent behavior** — the checksum reflects the data that the pod actually consumes via environment variables

**Operational impact:**

- **No immediate pod restart** — if your ConfigMap and Secret data are unchanged, the checksum will be identical to v1.3.0 (the data content is the same, only the calculation method improved)
- **Future upgrades** — subsequent chart upgrades that change only metadata will not trigger unnecessary pod restarts

> **Important:** This change improves the precision of the checksum calculation but does not change the configuration data itself. If you have not modified your `values.yaml`, the checksum values will remain the same after upgrade.

## Migration Impact

This upgrade has minimal operational impact:

| Aspect | Impact | Action Required |
|--------|--------|-----------------|
| Configuration | None — all values remain valid | None |
| Pod restart | Yes — label changes trigger rolling update | Monitor pod rollout |
| Service disruption | None — rolling update maintains availability | None |
| Secrets/ConfigMaps | None — data content unchanged | None |
| Application behavior | None — identical to v1.3.0 | None |

**Recommended upgrade process:**

1. Review the label changes in the [Pod Label Structure](#2-pod-label-structure) section
2. Preview the upgrade using `helm diff` (see below)
3. Perform the upgrade during a maintenance window (optional — rolling update maintains availability)
4. Monitor the pod rollout:

```bash
kubectl rollout status deployment/plugin-br-sisbajud -n sisbajud
```

5. Verify the new pods are running:

```bash
kubectl get pods -n sisbajud -l app.kubernetes.io/name=plugin-br-sisbajud
```

> **Note:** The rolling update strategy ensures zero downtime. The old pod remains running until the new pod passes readiness checks.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.3.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.3.1
```
<!-- {% endraw %} -->
