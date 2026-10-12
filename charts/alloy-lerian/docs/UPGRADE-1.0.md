# Helm Upgrade from v0.x to v1.x

This guide covers the upgrade from `alloy-lerian` chart version **0.0.0** to **1.0.0**. This is the initial release of the chart, introducing a complete telemetry collection pipeline for client clusters based on Grafana Alloy.

---

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Required Configuration Parameters](#required-configuration-parameters)
  - [Secret Provisioning](#secret-provisioning)
- **[Features](#features)**
  - [1. Dual-Role Architecture](#1-dual-role-architecture)
  - [2. Profile-Based Configuration](#2-profile-based-configuration)
  - [3. Origin Marking](#3-origin-marking)
  - [4. Namespace Perimeter Control](#4-namespace-perimeter-control)
  - [5. Cluster Object Metrics Collection](#5-cluster-object-metrics-collection)
  - [6. Container Usage Metrics](#6-container-usage-metrics)
  - [7. Node Infrastructure Metrics](#7-node-infrastructure-metrics)
  - [8. Regulated Data Sanitization](#8-regulated-data-sanitization)
  - [9. Fleet Management Integration](#9-fleet-management-integration)
  - [10. Destination Configuration](#10-destination-configuration)
  - [11. Retry and Queue Configuration](#11-retry-and-queue-configuration)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: Client Cluster (BYOC)](#scenario-1-client-cluster-byoc)
  - [Scenario 2: Own Environment](#scenario-2-own-environment)
- **[Configuration Reference](#configuration-reference)**
- **[New Environment Variables](#new-environment-variables)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Breaking Changes

### Required Configuration Parameters

Two parameters have **no default** and will cause the Helm render to fail if not provided:

| Parameter | v0.0.0 | v1.0.0 | Required |
|-----------|--------|--------|----------|
| `profile` | N/A | Must be `own` or `client` | Yes |
| `origin.id` | N/A | Must follow `<client>-<stage>` format | Yes |

> **Warning:** The chart will **refuse to render** if either `profile` or `origin.id` is empty. This is intentional to prevent deploying with invalid or default values that violate the schema.

**Migration Steps:**

1. Determine your deployment profile:
   - Use `own` if this is your own environment where you operate the infrastructure
   - Use `client` if this is a client cluster (BYOC) where you only operate specific namespaces

2. Define your origin identifier following the format `<client>-<stage>`:

```yaml
profile: "client"
origin:
  id: "acme-prd"
```

> **Important:** The origin ID marks **provenance**, not identity. Changing it for a live environment is a data migration, not a configuration change, as it becomes part of series identity at the destination.

### Secret Provisioning

The chart requires a pre-existing secret for destination authentication in `client` profile.

| Setting | v0.0.0 | v1.0.0 |
|---------|--------|--------|
| Secret creation | N/A | **Must be created manually before install** |
| Secret name | N/A | `alloy-lerian` (configurable via `destination.credential.secretName`) |
| Secret key | N/A | `telemetry-token` (configurable via `destination.credential.secretKey`) |

**Migration Steps:**

1. Create the secret before installing the chart:

```bash
kubectl create secret generic alloy-lerian \
  --from-literal=telemetry-token=<your-token-here> \
  -n alloy-lerian
```

2. The chart will reference this secret but never create it. If the secret does not exist and `profile: client` is set, the deployment will fail.

> **Note:** In `profile: own`, authentication is disabled by default as traffic goes through an internal load balancer within the VPC. The secret is not required in this case.

---

## Features

### 1. Dual-Role Architecture

The chart deploys **two separate Alloy instances** with different topologies:

- **Node role** (DaemonSet): Receives application telemetry pushed via OTLP on ports 4317 (gRPC) and 4318 (HTTP). Runs one replica per node.
- **Singleton role** (Deployment): Observes cluster-scoped state (events, cluster object metrics). Runs as a single replica to avoid duplicate writes.

**Configuration:**

```yaml
node:
  enabled: true

singleton:
  enabled: true
```

Both roles are enabled by default. The node role is required for application telemetry collection. The singleton role is required for cluster-level observability.

### 2. Profile-Based Configuration

The `profile` parameter controls collection scope and authentication requirements.

| Profile | Description | Node Metrics | Authentication |
|---------|-------------|--------------|----------------|
| `own` | Your own environment | Enabled by default | Disabled (internal LB) |
| `client` | Client cluster (BYOC) | Disabled by default | Required |

**Example for client cluster:**

```yaml
profile: "client"
origin:
  id: "acme-prd"
```

**Example for own environment:**

```yaml
profile: "own"
origin:
  id: "aws-staging"
```

> **Important:** The profile is **not inferable** from cluster properties. It must be explicitly set based on operational responsibility.

### 3. Origin Marking

Every telemetry record is marked with the environment it originated from via the `client.id` resource attribute.

**Configuration:**

```yaml
origin:
  id: "acme-prd"
```

The format is `<client>-<stage>` where:
- Client name is a **single word** (e.g., `acme-prd`, never `acme-corp-prd`)
- Stage is `stg` or `prd`
- The three SaaS environments (`aws-staging`, `aws-production`, `aws-devops`) are the only exempt values

> **Warning:** Changing the origin ID for a live environment orphans every existing series at the destination. This is a data migration, not a configuration change.

### 4. Namespace Perimeter Control

The chart filters telemetry by namespace to control collection scope.

**For `profile: client`:**

```yaml
collection:
  namespaces:
    include: "^(midaz|midaz-plugins)$"
```

Default includes only `midaz` and `midaz-plugins`. Override to collect from additional namespaces:

```yaml
collection:
  namespaces:
    include: "^(midaz|midaz-plugins|custom-namespace)$"
```

**For `profile: own`:**

```yaml
collection:
  namespaces:
    exclude: "^(kube-system|kube-public|kube-node-lease)$"
```

Default excludes system namespaces. Override to exclude additional namespaces.

> **Important:** An empty `include` list in `client` profile will cause the render to fail. This prevents accidentally collecting the entire cluster.

### 5. Cluster Object Metrics Collection

The chart deploys `kube-state-metrics` to collect cluster object state (pod phase, deployment replicas, etc.).

**Configuration:**

```yaml
kube-state-metrics:
  enabled: true

collection:
  clusterObjectAllowlist:
    - kube_pod_container_status_running
    - kube_pod_container_status_waiting
    - kube_pod_status_phase
    - kube_deployment_spec_replicas
    # ... 46 families total
```

The allowlist reduces collection from **184 families (5,272 series)** to **46 families (1,254 series)** — a 76% reduction.

**To reuse an existing kube-state-metrics deployment:**

```yaml
kube-state-metrics:
  enabled: false

collection:
  clusterObjectTarget: "http://kube-state-metrics.monitoring.svc.cluster.local:8080"
```

### 6. Container Usage Metrics

The chart scrapes container resource usage (CPU, memory, disk, network) from the kubelet's embedded cAdvisor.

**Configuration:**

```yaml
collection:
  containerUsage: true
```

This is **enabled by default** as it replaces the `kubeletstats` receiver from the previous agent.

**Namespace filtering for container usage:**

For `profile: own`:

```yaml
collection:
  excludeNamespaces:
    - ^kube-system$
    - ^kube-public$
    - ^kube-node-lease$
```

For `profile: client`:

```yaml
collection:
  onlyNamespaces:
    - ^midaz$
    - ^midaz-plugins$
```

> **Warning:** Disable `containerUsage` if the cluster already scrapes cAdvisor via another collector to avoid duplicate series.

**Allowlist:**

The chart collects **16 metric families** out of 78 exposed by cAdvisor, reducing series count from **90,948 to 4,893** (94.6% reduction).

```yaml
collection:
  containerUsageAllowlist:
    - container_cpu_usage_seconds_total
    - container_memory_usage_bytes
    - container_memory_working_set_bytes
    - container_spec_memory_limit_bytes
    # ... 16 families total
```

### 7. Node Infrastructure Metrics

The chart can deploy `prometheus-node-exporter` to collect node-level metrics (CPU, memory, filesystem, network of the **host**, not workloads).

**Configuration:**

```yaml
collection:
  nodeInfrastructure: false

node-exporter:
  enabled: false
```

This is **disabled by default** and only available in `profile: own`. The render will fail if enabled in `profile: client`.

> **Warning:** Measured on a 3-node cluster: node metrics produce **612 families and 46,575 series** — 11% of all series in that cluster. Enable only in environments where you operate the nodes.

**To enable:**

```yaml
profile: "own"
collection:
  nodeInfrastructure: true

node-exporter:
  enabled: true
```

### 8. Regulated Data Sanitization

The chart masks regulated data at the edge, in the `otelcol.processor.transform` stage. This is **always active and not configurable**.

What it masks, what it leaves in clear, and where it does not reach: [Regulated-data sanitisation](../README.md#regulated-data-sanitisation).

> **Important:** Sanitization rules are verified against the pinned Alloy version (1.18.1). Upgrading the Alloy dependency requires re-running the sanitization gate.

### 9. Fleet Management Integration

The chart supports remote configuration via Fleet Management.

**Configuration:**

```yaml
fleetManagement:
  enabled: true
  url: "https://fleet.lerian.io"
  pollFrequency: "1m"
```

When enabled:
- The local configuration file contains **only** `logging` and `remotecfg` blocks
- The collection pipeline is fetched from the Fleet endpoint
- Sanitization rules remain in the local config and cannot be disabled remotely

> **Warning:** With Fleet enabled, the agent collects **nothing** if the Fleet endpoint is unreachable. Disabling Fleet (`enabled: false`) renders the full local pipeline as a disaster recovery procedure.

### 10. Destination Configuration

The chart sends telemetry to a configurable endpoint with optional authentication.

**Configuration:**

```yaml
destination:
  endpoint: "https://telemetry.lerian.io"
  
  credential:
    secretName: "alloy-lerian"
    secretKey: "telemetry-token"
```

| Setting | Default | Description |
|---------|---------|-------------|
| `endpoint` | `https://telemetry.lerian.io` | Destination URL for telemetry |
| `credential.secretName` | `alloy-lerian` | Name of the secret containing the auth token |
| `credential.secretKey` | `telemetry-token` | Key within the secret |

**Authentication behavior:**

- `profile: client` — authentication is **required** (derived from profile)
- `profile: own` — authentication is **disabled** (traffic goes via internal LB)

> **Note:** Internal environments (`aws-staging`, `aws-production`) override the endpoint to use an internal load balancer that does not require authentication.

### 11. Retry and Queue Configuration

The chart configures in-memory queuing and retry behavior for transient failures.

**Configuration:**

```yaml
destination:
  queue:
    size: 1000
    singletonSize: 5000
    consumers: 10
    blockOnOverflow: false
  
  retry:
    maxElapsedTime: "5m"
```

| Setting | Default | Description |
|---------|---------|-------------|
| `queue.size` | `1000` | Queue size for node role |
| `queue.singletonSize` | `5000` | Queue size for singleton role (deeper to handle event replay burst) |
| `queue.consumers` | `10` | Number of concurrent consumers |
| `queue.blockOnOverflow` | `false` | Whether to block on queue full (default: discard) |
| `retry.maxElapsedTime` | `5m` | Maximum retry window before discarding |

> **Warning:** `blockOnOverflow: false` means **records are discarded** when the queue is full, and the application receives `200 OK`. Measured: 1800 sends → 300 responses, 58 retries, **800 discards**. Enable `blockOnOverflow: true` only if the application tolerates blocking.

---

## Deployment Scenarios

### Scenario 1: Client Cluster (BYOC)

Deploy the chart in a client-managed cluster where you only operate specific namespaces.

**Prerequisites:**

1. Create the authentication secret:

```bash
kubectl create secret generic alloy-lerian \
  --from-literal=telemetry-token=<your-token-here> \
  -n alloy-lerian
```

**values.yaml:**

```yaml
profile: "client"
origin:
  id: "acme-prd"

collection:
  namespaces:
    include: "^(midaz|midaz-plugins)$"
  
  containerUsage: true
  onlyNamespaces:
    - ^midaz$
    - ^midaz-plugins$
  
  nodeInfrastructure: false

kube-state-metrics:
  enabled: true

node-exporter:
  enabled: false

destination:
  endpoint: "https://telemetry.lerian.io"
  credential:
    secretName: "alloy-lerian"
    secretKey: "telemetry-token"
```

### Scenario 2: Own Environment

Deploy the chart in your own environment where you operate the entire cluster.

**values.yaml:**

```yaml
profile: "own"
origin:
  id: "aws-staging"

collection:
  namespaces:
    exclude: "^(kube-system|kube-public|kube-node-lease)$"
  
  containerUsage: true
  excludeNamespaces:
    - ^kube-system$
    - ^kube-public$
    - ^kube-node-lease$
  
  nodeInfrastructure: true

kube-state-metrics:
  enabled: true

node-exporter:
  enabled: true

destination:
  endpoint: "http://internal-lb.vpc.local"
  credential:
    enabled: false
```

> **Note:** Internal environments override the endpoint to use an internal load balancer. Authentication is disabled as traffic does not leave the VPC.

---

## Configuration Reference

### Global Settings

```yaml
nameOverride: ""
fullnameOverride: ""

global:
  imageRegistry: ""
  imagePullSecrets: []
```

### Profile and Origin

```yaml
profile: "client"  # Required: "own" or "client"

origin:
  id: "acme-prd"  # Required: <client>-<stage> format
```

### Destination

```yaml
destination:
  endpoint: "https://telemetry.lerian.io"
  
  credential:
    secretName: "alloy-lerian"
    secretKey: "telemetry-token"
  
  queue:
    size: 1000
    singletonSize: 5000
    consumers: 10
    blockOnOverflow: false
  
  retry:
    maxElapsedTime: "5m"
```

### Collection

```yaml
collection:
  interval: "60s"  # Minimum 60s, enforced
  
  namespaces:
    include: ""  # Regex for client profile
    exclude: ""  # Regex for own profile
  
  clusterObjectTarget: ""  # Empty = use our own kube-state-metrics
  
  nodeInfrastructure: false  # Only available in profile: own
  
  containerUsage: true
  
  excludeNamespaces:  # For profile: own
    - ^kube-system$
    - ^kube-public$
    - ^kube-node-lease$
  
  onlyNamespaces:  # For profile: client
    - ^midaz$
    - ^midaz-plugins$
  
  containerUsageTarget: ""  # Empty = via API server
  
  clusterObjectAllowlist:
    - kube_pod_container_status_running
    - kube_pod_container_status_waiting
    # ... 46 families total
  
  containerUsageAllowlist:
    - container_cpu_usage_seconds_total
    - container_memory_usage_bytes
    # ... 16 families total
```

### Fleet Management

```yaml
fleetManagement:
  enabled: true
  url: "https://fleet.lerian.io"
  pollFrequency: "1m"
```

### Dependencies

```yaml
node:
  enabled: true

singleton:
  enabled: true

kube-state-metrics:
  enabled: true

node-exporter:
  enabled: false
```

### Receiver Settings

```yaml
receiver:
  preserveLegacyTimeouts: false  # Set true to restore pre-v1.18.0 no-timeout behavior
```

---

## New Environment Variables

The following environment variables are injected into the Alloy containers:

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOY_CLIENT_ID` | Value of `origin.id` | Origin identifier for telemetry marking |
| `ALLOY_DESTINATION_ENDPOINT` | Value of `destination.endpoint` | Destination URL for telemetry export |

These are set automatically by the chart and should not be overridden manually.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 1.0.0 -n alloy-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 1.0.0 -n alloy-lerian
```
