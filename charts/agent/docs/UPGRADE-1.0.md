# Helm Upgrade from v0.x to v1.x

This guide helps operators deploy the **Lerian BYOC agent** chart for the first time at version **1.0.0**. Since this is the initial release (upgrading from a non-existent v0.0.0), this document serves as a deployment guide rather than a traditional upgrade guide.

## Topics

- **[Overview](#overview)**
- **[Prerequisites](#prerequisites)**
- **[Configuration Reference](#configuration-reference)**
  - [Required Configuration](#required-configuration)
  - [Agent Identity and Authentication](#agent-identity-and-authentication)
  - [Control Plane Connection](#control-plane-connection)
  - [Managed Namespaces](#managed-namespaces)
  - [Chart Registry Credentials](#chart-registry-credentials)
  - [Resource Limits](#resource-limits)
  - [Network Policies](#network-policies)
  - [Security Context](#security-context)
  - [Observability](#observability)
  - [Secret Vault Integration](#secret-vault-integration)
  - [Additional CA Trust](#additional-ca-trust)
- **[Deployment Scenarios](#deployment-scenarios)**
  - [Scenario 1: First-time deployment with enrollment token](#scenario-1-first-time-deployment-with-enrollment-token)
  - [Scenario 2: Deployment with per-agent token](#scenario-2-deployment-with-per-agent-token)
  - [Scenario 3: Using existing secrets](#scenario-3-using-existing-secrets)
  - [Scenario 4: Multi-namespace management](#scenario-4-multi-namespace-management)
  - [Scenario 5: Private chart registry](#scenario-5-private-chart-registry)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The **Lerian BYOC (Bring Your Own Cluster) agent** is a Kubernetes application that runs in your cluster and executes Helm operations assigned by the Lerian control plane. It maintains an outbound-only connection to the control plane and never accepts inbound traffic.

**Key characteristics:**

- Single replica per cluster (supported model)
- Polls control plane over HTTPS
- Executes Helm install/upgrade/uninstall operations
- Requires explicit namespace permissions
- Supports OCI chart registries with authentication
- Integrates with External Secrets Operator for vault-backed credentials

## Prerequisites

Before deploying the agent chart v1.0.0, ensure:

1. **Kubernetes version**: 1.33.0 or newer (as specified in `kubeVersion: ">=1.33.0-0"`)
2. **Helm version**: 3.x
3. **Control plane access**: You have a Lerian control plane URL (https://)
4. **Agent token**: Either:
   - An enrollment token from `POST /api/tenants/:id/agents/enrollments`, OR
   - A per-agent token and agent ID from `POST /api/tenants/:id/agents`
5. **Namespace permissions**: All namespaces the agent will manage must already exist
6. **Network access**: Outbound HTTPS to control plane and chart registries

> **Important:** The agent requires Kubernetes 1.33.0+. Verify your cluster version before proceeding.

## Configuration Reference

### Required Configuration

The following values **must** be set for the agent to function:

| Field | Required | Description |
|-------|----------|-------------|
| `agent.configmap.CONTROL_PLANE_URL` | Yes | Base URL of the Lerian control plane (must be https://) |
| `agent.secrets.AGENT_TOKEN` | Yes* | Agent authentication token (enrollment or per-agent) |
| `agent.secrets.AGENT_ID` | Conditional | Agent UUID (required only with per-agent token, leave empty with enrollment token) |

*Unless using `agent.useExistingSecret: true`

**Minimal values.yaml:**

```yaml
agent:
  configmap:
    CONTROL_PLANE_URL: "https://control.lerian.studio"
  secrets:
    AGENT_TOKEN: "lerian_enroll_abc123..."
    # AGENT_ID: "" # Leave empty for enrollment token
```

> **Warning:** `CONTROL_PLANE_URL` must be an https:// URL. The agent sends its bearer token on every request. Only set `AGENT_ALLOW_INSECURE_HTTP: "true"` for isolated dev/test clusters.

### Agent Identity and Authentication

The agent supports two authentication modes:

#### Option 1: Enrollment Token (First-time Setup)

Use a single-use enrollment token obtained from the control plane:

```yaml
agent:
  secrets:
    AGENT_TOKEN: "lerian_enroll_..."
    AGENT_ID: ""
```

The agent will exchange this token for a permanent per-agent token on first boot.

#### Option 2: Per-Agent Token

Use a permanent token and agent ID from a previous registration:

```yaml
agent:
  secrets:
    AGENT_TOKEN: "lerian_agent_..."
    AGENT_ID: "550e8400-e29b-41d4-a716-446655440000"
```

#### Option 3: Existing Secret

Reference an existing Kubernetes secret instead of creating one via the chart:

```yaml
agent:
  useExistingSecret: true
  existingSecretName: "my-agent-credentials"
```

The secret must contain keys:
- `AGENT_TOKEN` (required)
- `AGENT_ID` (required if using per-agent token)

### Control Plane Connection

| Flag | Default | Description |
|------|---------|-------------|
| `CONTROL_PLANE_URL` | (none) | Base URL of the Lerian control plane |
| `AGENT_ALLOW_INSECURE_HTTP` | `"false"` | Allow http:// URLs (dev/test only) |
| `HEARTBEAT_INTERVAL` | `"30s"` | How often the agent polls the control plane |
| `MAX_RETRY_ATTEMPTS` | `"3"` | Total attempts at one control-plane call before giving up |
| `RETRY_BACKOFF_INITIAL` | `"1s"` | First retry backoff (grows exponentially) |
| `RETRY_BACKOFF_MAX` | `"30s"` | Ceiling of the retry backoff |
| `CIRCUIT_BREAKER_MAX_FAILURES` | `"5"` | Consecutive failures that open the circuit breaker |
| `CIRCUIT_BREAKER_TIMEOUT` | `"30s"` | How long the circuit breaker stays open |

**Example configuration:**

```yaml
agent:
  configmap:
    CONTROL_PLANE_URL: "https://control.lerian.studio"
    HEARTBEAT_INTERVAL: "60s"
    MAX_RETRY_ATTEMPTS: "5"
    RETRY_BACKOFF_MAX: "60s"
```

### Managed Namespaces

The agent requires explicit RBAC permissions for every namespace it may write to. By default, it can only manage releases in its own namespace.

| Field | Default | Description |
|-------|---------|-------------|
| `agent.managedNamespaces` | `[]` (release namespace only) | List of namespaces the agent may install/upgrade/uninstall releases in |

**Example: Multi-namespace management**

```yaml
agent:
  managedNamespaces:
    - "default"
    - "production"
    - "staging"
```

> **Important:** All namespaces in `managedNamespaces` must already exist. The chart does not create them. Adding a namespace requires a `helm upgrade` of this chart to update RBAC.

### Chart Registry Credentials

If your Helm charts are in a private OCI registry, provide credentials:

#### Option 1: Username and Password

```yaml
agent:
  chartRegistry:
    host: "ghcr.io/lerianstudio"
    username: "myuser"
    password: "mytoken"
```

#### Option 2: Existing Docker Config Secret

```yaml
agent:
  chartRegistry:
    existingSecret: "my-registry-secret"
```

The secret must be of type `kubernetes.io/dockerconfigjson`.

| Field | Default | Description |
|-------|---------|-------------|
| `agent.chartRegistry.host` | `""` | Registry host (e.g., "ghcr.io/lerianstudio") |
| `agent.chartRegistry.username` | `""` | Registry username |
| `agent.chartRegistry.password` | `""` | Registry password or token |
| `agent.chartRegistry.existingSecret` | `""` | Name of existing dockerconfigjson secret |

> **Note:** The host is case-insensitive and may include an organization path. Schemes (`oci://`, `https://`) and trailing slashes are automatically normalized.

### Resource Limits

Default resource configuration:

```yaml
agent:
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi
```

Adjust based on workload:

```yaml
agent:
  resources:
    limits:
      cpu: 500m
      memory: 256Mi
    requests:
      cpu: 200m
      memory: 128Mi
```

### Network Policies

The chart creates NetworkPolicies for egress control by default.

| Field | Default | Description |
|-------|---------|-------------|
| `agent.networkPolicy.enabled` | `true` | Enable NetworkPolicies |
| `agent.networkPolicy.kubernetesApiCidr` | `"0.0.0.0/0"` | Kubernetes API server CIDR (443/6443) |
| `agent.networkPolicy.controlPlaneCidr` | `"0.0.0.0/0"` | Control plane and chart registry CIDR |
| `agent.networkPolicy.extraEgress` | `[]` | Additional egress rules |

**Example: Restricted network policies**

```yaml
agent:
  networkPolicy:
    enabled: true
    kubernetesApiCidr: "10.0.0.0/16"
    controlPlaneCidr: "203.0.113.0/24"
    extraEgress:
      - to:
          - ipBlock:
              cidr: "198.51.100.0/24"
        ports:
          - protocol: TCP
            port: 443
```

> **Warning:** Narrowing CIDRs may block certificate watching. Add addresses your releases publish on port 443 to `extraEgress`.

### Security Context

The agent runs as a non-root user with a read-only root filesystem:

```yaml
agent:
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 65532
    runAsGroup: 65532
    fsGroup: 65532
    seccompProfile:
      type: RuntimeDefault

  securityContext:
    runAsNonRoot: true
    capabilities:
      drop:
        - ALL
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault
```

These defaults follow security best practices and should not be changed unless required by your environment.

### Observability

#### Prometheus Metrics

The agent exposes metrics on port 8081 at `/metrics`.

**Enable ServiceMonitor (requires Prometheus Operator):**

```yaml
agent:
  serviceMonitor:
    enabled: true
    interval: 30s
    scrapeTimeout: 10s
    labels:
      release: prometheus
```

**Enable PrometheusRule for baseline alerts:**

```yaml
agent:
  prometheusRule:
    enabled: true
    volumeAlerts:
      enabled: true
      freeRatio: 0.15
      for: 15m
```

| Field | Default | Description |
|-------|---------|-------------|
| `agent.serviceMonitor.enabled` | `false` | Create ServiceMonitor for Prometheus Operator |
| `agent.serviceMonitor.interval` | `"30s"` | Scrape interval |
| `agent.serviceMonitor.labels` | `{}` | Extra labels (e.g., `release: prometheus`) |
| `agent.prometheusRule.enabled` | `false` | Create PrometheusRule with baseline alerts |
| `agent.prometheusRule.volumeAlerts.enabled` | `false` | Enable disk-filling alerts for managed volumes |
| `agent.prometheusRule.volumeAlerts.freeRatio` | `0.15` | Alert when less than this fraction is free |
| `agent.prometheusRule.volumeAlerts.for` | `"15m"` | Alert duration threshold |

#### OpenTelemetry

```yaml
agent:
  configmap:
    ENABLE_TELEMETRY: "true"
    OTEL_SERVICE_NAME: "lerian-agent"
    OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector:4317"
```

| Flag | Default | Description |
|------|---------|-------------|
| `ENABLE_TELEMETRY` | `"false"` | Enable OpenTelemetry tracing |
| `OTEL_SERVICE_NAME` | `"lerian-agent"` | Service name in traces |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `""` | OTLP collector endpoint |

#### Health Endpoints

- Liveness: `http://<service>:8081/health/live`
- Readiness: `http://<service>:8081/health/ready`

### Secret Vault Integration

Integrate with External Secrets Operator to store credentials in your vault:

```yaml
agent:
  secretVault:
    provider: "aws"
    storeName: "my-secret-store"
    storeKind: "ClusterSecretStore"
    pathPrefix: "lerian/deployer"
    refreshInterval: "1h"
```

| Field | Default | Description |
|-------|---------|-------------|
| `agent.secretVault.provider` | `""` | Vault provider: `aws`, `gcp`, or `azure` (empty disables) |
| `agent.secretVault.storeName` | `""` | Name of the External Secrets store |
| `agent.secretVault.storeKind` | `""` | `ClusterSecretStore` or `SecretStore` |
| `agent.secretVault.pathPrefix` | `""` | Vault path prefix (default: `lerian/deployer`) |
| `agent.secretVault.refreshInterval` | `""` | How often to refresh from vault (default: `1h`, never `0`) |

> **Note:** Requires External Secrets Operator installed and a store already configured.

### Additional CA Trust

Trust custom root certificates alongside public roots:

```yaml
agent:
  trust:
    additionalCABundle: "my-ca-bundle"
```

The value must be the name of a ConfigMap in the release namespace containing PEM-encoded certificates.

### Helm Operation Settings

| Flag | Default | Description |
|------|---------|-------------|
| `HELM_TIMEOUT` | `"15m"` | Max duration for one Helm install/upgrade |
| `MAX_CONCURRENT_WORK` | `"3"` | Number of operations the agent runs simultaneously |

**Example: Increase timeout for large deployments**

```yaml
agent:
  configmap:
    HELM_TIMEOUT: "30m"
    MAX_CONCURRENT_WORK: "5"
  terminationGracePeriodSeconds: 2400  # 30m + 5m rollback buffer
```

> **Important:** When increasing `HELM_TIMEOUT`, also increase `terminationGracePeriodSeconds` to allow operations to complete before SIGKILL.

### Registry Allowlists

Control which registries the agent may pull from:

| Flag | Default | Description |
|------|---------|-------------|
| `AGENT_ALLOWED_CHART_REGISTRIES` | `""` | Comma-separated list of allowed chart registries (empty = Lerian defaults) |
| `AGENT_ALLOWED_IMAGE_REGISTRIES` | `""` | Comma-separated list of registries for agent self-update (empty = ghcr.io/lerianstudio) |

**Example:**

```yaml
agent:
  configmap:
    AGENT_ALLOWED_CHART_REGISTRIES: "ghcr.io/lerianstudio,registry-1.docker.io/lerianstudio"
    AGENT_ALLOWED_IMAGE_REGISTRIES: "ghcr.io/lerianstudio"
```

> **Note:** Empty values use built-in Lerian defaults. There is no value meaning "any registry".

### Image Configuration

| Field | Default | Description |
|-------|---------|-------------|
| `agent.image.repository` | `ghcr.io/lerianstudio/agent` | Agent container image repository |
| `agent.image.tag` | `"1.0.0"` | Image tag (kept equal to appVersion) |
| `agent.image.digest` | `""` | Image digest (sha256:...), overrides tag |
| `agent.image.pullPolicy` | `IfNotPresent` | Image pull policy |

**Example: Pin to digest after control-plane update**

```yaml
agent:
  image:
    digest: "sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
```

> **Note:** Setting `digest` prevents `helm upgrade` from reverting a control-plane-driven self-update.

### Probes

Default probe configuration allows 600s startup time (covers enrollment retries):

```yaml
agent:
  startupProbe: {}
  livenessProbe: {}
  readinessProbe: {}
```

Override if needed:

```yaml
agent:
  startupProbe:
    httpGet:
      path: /health/live
      port: 8081
    initialDelaySeconds: 10
    periodSeconds: 10
    failureThreshold: 60
```

### Extra Environment Variables

Append custom environment variables (e.g., for corporate proxies):

```yaml
agent:
  extraEnvVars:
    - name: HTTPS_PROXY
      value: "http://proxy.corp.example.com:8080"
    - name: NO_PROXY
      value: "localhost,127.0.0.1,.cluster.local"
```

## Deployment Scenarios

### Scenario 1: First-time deployment with enrollment token

**Use case:** Initial agent deployment using a single-use enrollment token.

**Steps:**

1. Obtain an enrollment token from the control plane:

```bash
curl -X POST https://control.lerian.studio/api/tenants/my-tenant-id/agents/enrollments \
  -H "Authorization: Bearer $CONTROL_PLANE_TOKEN"
```

2. Create a values file:

```yaml
agent:
  configmap:
    CONTROL_PLANE_URL: "https://control.lerian.studio"
  secrets:
    AGENT_TOKEN: "lerian_enroll_abc123xyz..."
    AGENT_ID: ""
```

3. Install the chart:

```bash
helm install agent oci://registry-1.docker.io/lerianstudio/agent-helm \
  --version 1.0.0 \
  --namespace agent \
  --create-namespace \
  --values values.yaml
```

4. Verify the agent connected:

```bash
kubectl -n agent logs deploy/lerian-agent | grep -i heartbeat
```

### Scenario 2: Deployment with per-agent token

**Use case:** Deploy with a permanent agent token and ID from a previous registration.

**Steps:**

1. Obtain a per-agent token and ID from the control plane:

```bash
curl -X POST https://control.lerian.studio/api/tenants/my-tenant-id/agents \
  -H "Authorization: Bearer $CONTROL_PLANE_TOKEN"
```

2. Create a values file:

```yaml
agent:
  configmap:
    CONTROL_PLANE_URL: "https://control.lerian.studio"
  secrets:
    AGENT_TOKEN: "lerian_agent_def456uvw..."
    AGENT_ID: "550e8400-e29b-41d4-a716-446655440000"
```

3. Install the chart:

```bash
helm install agent oci://registry-1.docker.io/lerianstudio/agent-helm \
  --version 1.0.0 \
  --namespace agent \
  --create-namespace \
  --values values.yaml
```

### Scenario 3: Using existing secrets

**Use case:** Credentials are managed outside Helm (e.g., via External Secrets Operator).

**Steps:**

1. Create the secret manually or via your secret management tool:

```bash
kubectl create secret generic my-agent-credentials \
  --namespace agent \
  --from-literal=AGENT_TOKEN="lerian_agent_..." \
  --from-literal=AGENT_ID="550e8400-e29b-41d4-a716-446655440000"
```

2. Create a values file:

```yaml
agent:
  configmap:
    CONTROL_PLANE_URL: "https://control.lerian.studio"
  useExistingSecret: true
  existingSecretName: "my-agent-credentials"
```

3. Install the chart:

```bash
helm install agent oci://registry-1.docker.io/lerianstudio/agent-helm \
  --version 1.0.0 \
  --namespace agent \
  --create-namespace \
  --values values.yaml
```

### Scenario 4: Multi-namespace management

**Use case:** Agent needs to manage releases across multiple namespaces.

**Steps:**

1. Create all target namespaces:

```bash
kubectl create namespace production
kubectl create namespace staging
kubectl create namespace development
```

2. Create a values file:

```yaml
agent:
  configmap:
    CONTROL_PLANE_URL: "https://control.lerian.studio"
  secrets:
    AGENT_TOKEN: "lerian_enroll_..."
    AGENT_ID: ""
  managedNamespaces:
    - "production"
    - "staging"
    - "development"
```

3. Install the chart:

```bash
helm install agent oci://registry-1.docker.io/lerianstudio/agent-helm \
  --version 1.0.0 \
  --namespace agent \
  --create-namespace \
  --values values.yaml
```

> **Important:** The chart creates a Role and RoleBinding in each managed namespace. Adding a namespace later requires a `helm upgrade`.

### Scenario 5: Private chart registry

**Use case:** Helm charts are stored in a private OCI registry requiring authentication.

**Steps:**

1. Create a values file with registry credentials:

```yaml
agent:
  configmap:
    CONTROL_PLANE_URL: "https://control.lerian.studio"
  secrets:
    AGENT_TOKEN: "lerian_enroll_..."
    AGENT_ID: ""
  chartRegistry:
    host: "ghcr.io/myorg"
    username: "myuser"
    password: "ghp_mytoken123..."
```

2. Install the chart:

```bash
helm install agent oci://registry-1.docker.io/lerianstudio/agent-helm \
  --version 1.0.0 \
  --namespace agent \
  --create-namespace \
  --values values.yaml
```

**Alternative: Using an existing dockerconfigjson secret**

1. Create the secret:

```bash
kubectl create secret docker-registry my-registry-secret \
  --namespace agent \
  --docker-server=ghcr.io \
  --docker-username=myuser \
  --docker-password=ghp_mytoken123...
```

2. Create a values file:

```yaml
agent:
  configmap:
    CONTROL_PLANE_URL: "https://control.lerian.studio"
  secrets:
    AGENT_TOKEN: "lerian_enroll_..."
    AGENT_ID: ""
  chartRegistry:
    existingSecret: "my-registry-secret"
```

3. Install the chart:

```bash
helm install agent oci://registry-1.docker.io/lerianstudio/agent-helm \
  --version 1.0.0 \
  --namespace agent \
  --create-namespace \
  --values values.yaml
```

## Preview changes before upgrading

```bash
helm diff upgrade agent oci://registry-1.docker.io/lerianstudio/agent-helm --version 1.0.0 -n agent
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade agent oci://registry-1.docker.io/lerianstudio/agent-helm --version 1.0.0 -n agent
```
