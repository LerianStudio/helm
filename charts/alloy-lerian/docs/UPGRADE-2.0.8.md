# Helm Upgrade from v2.0.7 to v2.0.8

This guide covers the upgrade from `alloy-lerian` chart version **2.0.7** to **2.0.8**. This patch release removes outdated documentation comments, corrects internal environment references, adds explicit RBAC rules for both agent roles, and introduces a new global registry setting for agent images.

---

## Topics

- **[Fixes](#fixes)**
  - [1. Documentation Cleanup](#1-documentation-cleanup)
  - [2. Internal Environment Reference Corrections](#2-internal-environment-reference-corrections)
  - [3. Explicit RBAC Rules for Agent Roles](#3-explicit-rbac-rules-for-agent-roles)
  - [4. Global Image Registry for Agent Images](#4-global-image-registry-for-agent-images)
  - [5. Kube-State-Metrics Collector Exclusions](#5-kube-state-metrics-collector-exclusions)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Fixes

### 1. Documentation Cleanup

Several outdated documentation comments have been removed from `Chart.yaml` and `values.yaml`.

**What changed:**

1. Removed the Lerian docs reference comment from `Chart.yaml`:

```yaml
# Before (v2.0.7):
icon: https://avatars.githubusercontent.com/u/148895005?s=200&v=4

# Refer to the Lerian docs for component documentation:
# https://docs.lerian.studio/docs/midaz-components

dependencies:
  # ...

# After (v2.0.8):
icon: https://avatars.githubusercontent.com/u/148895005?s=200&v=4

dependencies:
  # ...
```

2. Simplified the `origin.id` description in `values.yaml`:

```yaml
# Before (v2.0.7):
# Form: <client>-<stage>, lowercase, stage = stg | prd. The client name is a
# SINGLE word — acme-prd, never acme-corp-prd. Our three SaaS environments are the
# only exempt values; internal test clusters do not run this chart and get no
# exemption.

# After (v2.0.8):
# Form: <client>-<stage>, lowercase, stage = stg | prd. The client name is a
# SINGLE word — acme-prd, never acme-corp-prd. Our three SaaS environments are the
# only exempt values.
```

**What this means:**

No operational impact. These are documentation-only changes that remove references to internal test clusters and outdated documentation links.

**Migration Steps:**

No action required.

### 2. Internal Environment Reference Corrections

All references to specific internal environment names have been replaced with generic descriptions throughout the chart.

**What changed:**

The chart previously referenced specific internal environment names (e.g., `aws-devops`, `benedita`, `aws-staging`, `aws-production`) in comments and documentation. These have been replaced with generic terms like "internal environment", "internal cluster", or "ambiente interno".

**Examples:**

| Location | Before (v2.0.7) | After (v2.0.8) |
|----------|-----------------|----------------|
| `values.yaml` destination.endpoint comment | `⚠️ Os ambientes internos aws-* SOBRESCREVEM` | `Para usar outro destino, mude só esta entrada` |
| `values.yaml` destination.credential comment | `POR QUE own NÃO AUTENTICA — é topologia...` | `Em own a autenticação do destino fica desligada por padrão` |
| `values.yaml` destination.queue.singletonSize comment | `MEASURED on benedita: with the node role's 1000` | `MEASURED on an internal cluster: with the node role's 1000` |
| `values.yaml` collection.nodeInfrastructure comment | `⚠️ VOLUME. Medido na benedita: 3 nós produzem` | `⚠️ VOLUME. Medido em cluster interno: 3 nós produzem` |
| `_config.tpl` | `MEDIDO em aws-devops:` | `MEDIDO em ambiente interno:` |

**What this means:**

No operational impact. These are documentation-only changes that remove references to specific internal environment names. The technical content and behavior remain unchanged.

**Migration Steps:**

No action required.

### 3. Explicit RBAC Rules for Agent Roles

The chart now explicitly defines RBAC rules for both the node and singleton roles, reducing permissions from the upstream Alloy chart default.

**What changed:**

**Before (v2.0.7):**

The chart relied on the upstream `grafana/alloy` subchart's default RBAC rules, which included permissions for `configmaps`, `secrets`, and `pods/log` that no component in the rendered pipeline uses.

**After (v2.0.8):**

The chart defines a minimal RBAC ruleset and applies it to both roles:

```yaml
node:
  enabled: true
  rbac:
    rules: &agentRules
      - apiGroups: ["", "discovery.k8s.io", "networking.k8s.io"]
        resources: ["endpoints", "endpointslices", "ingresses", "pods", "services"]
        verbs: ["get", "list", "watch"]
      - apiGroups: [""]
        resources: ["pods", "namespaces"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["monitoring.grafana.com"]
        resources: ["podlogs"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["monitoring.coreos.com"]
        resources: ["prometheusrules"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["monitoring.coreos.com"]
        resources: ["alertmanagerconfigs"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["monitoring.coreos.com"]
        resources: ["podmonitors", "servicemonitors", "probes", "scrapeconfigs"]
        verbs: ["get", "list", "watch"]
      - apiGroups: [""]
        resources: ["events"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["apps", "extensions"]
        resources: ["replicasets"]
        verbs: ["get", "list", "watch"]

singleton:
  enabled: true
  rbac:
    rules: *agentRules
```

**What this means:**

1. The agent ServiceAccounts no longer have permissions to read `configmaps`, `secrets`, or `pods/log`
2. Both roles use the same RBAC ruleset (defined once with a YAML anchor and referenced in both places)
3. The permissions match what the rendered Alloy configuration actually uses

**Migration Steps:**

No action required. The chart will update the ClusterRole on upgrade.

> **Note:** If you have custom Alloy components that read ConfigMaps, Secrets, or pod logs through the Kubernetes API, you must add those permissions back by overriding `node.rbac.rules` and `singleton.rbac.rules`.

**Example: Restoring ConfigMap read permissions:**

```yaml
node:
  rbac:
    rules:
      - apiGroups: ["", "discovery.k8s.io", "networking.k8s.io"]
        resources: ["endpoints", "endpointslices", "ingresses", "pods", "services"]
        verbs: ["get", "list", "watch"]
      - apiGroups: [""]
        resources: ["pods", "namespaces", "configmaps"]
        verbs: ["get", "list", "watch"]
      # ... rest of the rules

singleton:
  rbac:
    rules:
      - apiGroups: ["", "discovery.k8s.io", "networking.k8s.io"]
        resources: ["endpoints", "endpointslices", "ingresses", "pods", "services"]
        verbs: ["get", "list", "watch"]
      - apiGroups: [""]
        resources: ["pods", "namespaces", "configmaps"]
        verbs: ["get", "list", "watch"]
      # ... rest of the rules
```

> **Warning:** `rbac.rules` is a list, so declaring it replaces the chart default entirely. You must repeat all default entries when overriding.

### 4. Global Image Registry for Agent Images

The chart now supports a separate registry override for the agent and config-reloader images.

**What changed:**

**Before (v2.0.7):**

The chart had only `global.imageRegistry`, which applied to `kube-state-metrics` and `node-exporter` images. The agent and config-reloader images came from the upstream Alloy chart's default registry, which reads `global.image.registry` (not `global.imageRegistry`).

**After (v2.0.8):**

The chart now documents both registry settings:

```yaml
global:
  # Registry for kube-state-metrics and node-exporter images.
  imageRegistry: ""
  # Registry for the agent and config-reloader images. The upstream Alloy chart
  # reads this key, not `imageRegistry`: set both to mirror every image.
  image:
    registry: ""
  imagePullSecrets: []
```

**What this means:**

1. `global.imageRegistry` applies to `kube-state-metrics` and `node-exporter` only
2. `global.image.registry` applies to the agent and config-reloader images
3. To mirror all images from a private registry, you must set **both** fields

**Migration Steps:**

#### Option 1: Keep existing behavior (recommended)

No action required. The chart will continue pulling images from their default registries.

#### Option 2: Mirror all images to a private registry

Set both registry fields to your private registry:

```yaml
global:
  imageRegistry: "my-registry.example.com"
  image:
    registry: "my-registry.example.com"
```

> **Important:** The `NOTES.txt` output after upgrade will warn if `global.imageRegistry` is set but `global.image.registry` is not:

```
Atenção: `global.imageRegistry` vale para kube-state-metrics e node-exporter. As
imagens do agente e do config-reloader usam `global.image.registry`.
```

### 5. Kube-State-Metrics Collector Exclusions

The chart now explicitly disables the `secrets` and `configmaps` collectors in `kube-state-metrics`.

**What changed:**

**Before (v2.0.7):**

The chart relied on the upstream `kube-state-metrics` default collectors, which include `secrets` and `configmaps`.

**After (v2.0.8):**

The chart explicitly excludes these collectors:

```yaml
kube-state-metrics:
  autosharding:
    enabled: false
  # No kept metric comes from Secrets or ConfigMaps, so the exporter neither
  # lists nor watches them.
  collectorsExclude:
    - secrets
    - configmaps
```

**What this means:**

1. `kube-state-metrics` will no longer list or watch Secrets and ConfigMaps
2. No metrics from the `collection.clusterObjectAllowlist` come from these resource types
3. This reduces the API server load and the permissions required by the `kube-state-metrics` ServiceAccount

**Migration Steps:**

No action required. The chart will update the `kube-state-metrics` Deployment on upgrade.

> **Warning:** If you have added custom metrics to `collection.clusterObjectAllowlist` that come from Secrets or ConfigMaps (e.g., `kube_secret_info`, `kube_configmap_info`), you must remove these collectors from the exclusion list:

```yaml
kube-state-metrics:
  collectorsExclude: []
```

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm -n monitoring --version 2.0.8
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://ghcr.io/lerianstudio/alloy-lerian-helm -n monitoring --version 2.0.8
```
