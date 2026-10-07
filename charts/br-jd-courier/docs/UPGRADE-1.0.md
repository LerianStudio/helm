# Helm Upgrade from v0.x to v1.x

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Chart is now available](#chart-is-now-available)
  - [Mandatory Secret requirement](#mandatory-secret-requirement)
  - [Single-writer replica enforcement](#single-writer-replica-enforcement)
  - [Configuration restrictions](#configuration-restrictions)
- **[Features](#features)**
  - [1. Multi-role deployment architecture](#1-multi-role-deployment-architecture)
  - [2. Database migrations](#2-database-migrations)
  - [3. Telemetry configuration](#3-telemetry-configuration)
  - [4. Security hardening](#4-security-hardening)
  - [5. Graceful shutdown tuning](#5-graceful-shutdown-tuning)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Breaking Changes

### Chart is now available

| Setting | v0.0.0 | v1.0.0 |
|---------|---------|---------|
| Chart existence | No chart published | Chart published as `br-jd-courier-helm` |
| Chart name | N/A | `br-jd-courier-helm` |
| Resource prefix | N/A | Defaults to `br-jd-courier` (literal, not chart name) |

**Before (v0.0.0):**

No Helm chart existed. The br-jd-courier application was deployed through other means (manual manifests, custom tooling, or not deployed via Kubernetes).

**After (v1.0.0):**

The chart is now published and manages four role-based Deployments from a single container image:
- `spb-consumer` (single replica, destructive queue reader)
- `spb-sender` (multi-replica, SOAP surface)
- `pix-ingress` (multi-replica, Pix delivery receiver)
- `admin` (single replica, administrative surface)

> **Important:** If you were deploying br-jd-courier manually, you must migrate to this Helm chart. The chart enforces critical operational constraints (e.g., single-writer protection) that manual deployments may not respect.

### Mandatory Secret requirement

| Setting | v0.0.0 | v1.0.0 |
|---------|---------|---------|
| Secret management | N/A | `secrets.existingSecret` must reference a pre-existing Secret |
| Secret creation | N/A | Chart **never** renders Secrets — operator must create them |

The chart requires a pre-existing Kubernetes Secret containing:
- `LICENSE_KEY` (mandatory, referenced by name in every pod)
- `POSTGRES_PASSWORD`
- `DATABASE_URL` (for migration Job)
- Any other secret keys your configuration requires (e.g., `JD_PASSWORD`, `REDIS_PASSWORD`)

> **Warning:** The chart will **refuse to render** if you attempt to set secret values in `config` or any other values block. All secrets must arrive through `secrets.existingSecret`.

**Migration action required:**

1. Create the Secret before installing the chart:

```bash
kubectl create secret generic br-jd-courier-secrets \
  --from-literal=LICENSE_KEY='your-license-key' \
  --from-literal=POSTGRES_PASSWORD='your-db-password' \
  --from-literal=DATABASE_URL='postgresql://user:pass@host:5432/dbname' \
  -n br-jd-courier
```

2. Reference it in your values:

```yaml
secrets:
  existingSecret: "br-jd-courier-secrets"
```

If `secrets.existingSecret` is empty, the chart defaults to the release fullname (e.g., `br-jd-courier` for a release named `br-jd-courier`).

### Single-writer replica enforcement

| Setting | v0.0.0 | v1.0.0 |
|---------|---------|---------|
| `spb-consumer` replicas | N/A | **Must be exactly 1** — chart refuses to render if > 1 |
| Deployment strategy | N/A | `Recreate` (not `RollingUpdate`) for `spb-consumer` |

The `spb-consumer` role drains a **destructive vendor queue**. Running multiple replicas causes message loss.

**The chart enforces this at three layers:**

1. **Render-time guard:** `helm template` or `helm install` fails if `roles.spbConsumer.replicas > 1`
2. **Deployment strategy:** Uses `Recreate` to prevent two pods during rollout
3. **Boot-time guard:** The application itself reads the rail registry and refuses to start if misconfigured

> **Warning:** Never scale `spb-consumer` above 1 replica. The chart will refuse to render, but if you bypass Helm (e.g., `kubectl scale`), you will lose messages.

### Configuration restrictions

The chart **refuses to render** if any of the following keys appear in `config`:

| Refused Key | Reason |
|-------------|--------|
| `COURIER_ROLES` | Set automatically per Deployment by the chart |
| `SERVER_ADDRESS` | Derived from `ports.http` |
| `SOAP_SERVER_ADDRESS` | Derived from `ports.soap` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Set via `telemetry.otlpEndpoint` (supports `$(NODE_IP)` expansion) |
| `ALLOW_AUTH_DISABLED_LOCAL_ONLY` | Authentication is always on in chart installs |
| `LICENSE_KEY`, `DATABASE_URL`, `POSTGRES_PASSWORD`, `POSTGRES_REPLICA_PASSWORD`, `REDIS_PASSWORD`, `MULTI_TENANT_REDIS_PASSWORD`, `MULTI_TENANT_SERVICE_API_KEY`, `JD_PASSWORD` | Must arrive through `secrets.existingSecret` |
| `JD_PRIVATE_KEY_PEM` | The Courier holds no signing key — refused everywhere |

Additionally, the chart scans all rendered values for PEM private key blocks (`-----BEGIN ... PRIVATE KEY-----`) and refuses to render if any are found, regardless of the key name.

> **Important:** If you were setting any of these in your previous deployment configuration, you must migrate them to the appropriate values blocks (`secrets.existingSecret` for secrets, `ports.*` for addresses, `telemetry.otlpEndpoint` for OTLP).

---

## Features

### 1. Multi-role deployment architecture

The chart deploys four roles from a single container image, each with independent replica counts, resources, and Services:

```yaml
roles:
  spbConsumer:
    enabled: true
    replicas: 1  # MUST be 1
    resources: {}
  spbSender:
    enabled: true
    replicas: 2
    resources: {}
    service:
      type: ClusterIP
  pixIngress:
    enabled: true
    replicas: 2
    resources: {}
    service:
      type: ClusterIP
  admin:
    enabled: true
    replicas: 1
    resources: {}
    service:
      type: ClusterIP
```

Each role:
- Runs the same image (`jd-courier.image.repository:tag`)
- Gets `COURIER_ROLES` set automatically (e.g., `spb-consumer`, `spb-sender`)
- Shares the same ConfigMap (`config`) and Secret (`secrets.existingSecret`)
- Has its own Deployment, Service (if applicable), and resource limits

**New environment variables set per role:**

| Variable | Set By | Description |
|----------|--------|-------------|
| `COURIER_ROLES` | Chart (per Deployment) | The role this pod runs (e.g., `spb-consumer`, `admin`) |
| `POD_NAME` | Downward API | Used by `spb-consumer` for SPB drain lease holder identity |
| `NODE_IP` | Downward API | The pod's node IP, used in default `OTEL_EXPORTER_OTLP_ENDPOINT` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `telemetry.otlpEndpoint` | Where OTLP telemetry is sent (default: `$(NODE_IP):4317`) |
| `SERVER_ADDRESS` | Derived from `ports.http` | JSON/HTTP listener address (e.g., `:8080`) |
| `SOAP_SERVER_ADDRESS` | Derived from `ports.soap` | SOAP listener address (e.g., `:8081`, `spb-sender` only) |
| `LICENSE_KEY` | `secretKeyRef` from `secrets.existingSecret` | Application license key (mandatory) |

### 2. Database migrations

The chart includes a pre-install/pre-upgrade Job that runs `migrate up` against the Courier's database:

```yaml
migrations:
  enabled: true
  backoffLimit: 3
  activeDeadlineSeconds: 600
  resources: {}
```

**Restrictions:**

- **Single-tenant only:** The chart refuses to render the migration Job if `config.MULTI_TENANT_ENABLED` is `true`
- In multi-tenant mode, per-tenant migrations must be applied by a separate platform mechanism

> **Note:** The migration Job requires `DATABASE_URL` in the Secret referenced by `secrets.existingSecret`.

**To disable migrations:**

```yaml
migrations:
  enabled: false
```

### 3. Telemetry configuration

All roles send OTLP metrics and traces to a configurable endpoint:

```yaml
telemetry:
  otlpEndpoint: "$(NODE_IP):4317"
```

**Default behavior:**

- Sends to the collector on the pod's own node (Lerian convention)
- The chart sets `ALLOW_INSECURE_OTEL` automatically for this exact value, allowing plaintext in production
- Any other endpoint must use `https://` in production, or you must set `config.ALLOW_INSECURE_OTEL` with your own justification

**To send to a different collector:**

```yaml
telemetry:
  otlpEndpoint: "https://otel-collector.observability.svc.cluster.local:4317"
```

> **Important:** The chart expands `$(NODE_IP)` only for the default value. Custom endpoints must be fully qualified.

### 4. Security hardening

Every pod runs with:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  seccompProfile:
    type: RuntimeDefault

containers:
  - securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
```

- No service account token mounted (`automountServiceAccountToken: false`)
- Runs as non-root user `65532` (the image's `nonroot` user)
- Read-only root filesystem
- All capabilities dropped

### 5. Graceful shutdown tuning

The chart sets `terminationGracePeriodSeconds: 100` to allow the `spb-consumer` to finish persisting in-flight messages before SIGKILL:

**Shutdown sequence:**

| Time | Event |
|------|-------|
| t=0 | SIGTERM: rail stop starts (except HTTP) |
| t≤80 | Rail finishes: one read (15s) + one persist (60s) + 5s margin |
| t=12 | Readiness probe fails; HTTP drain starts (runs alongside rail stop) |
| After HTTP drain | Lifecycle hooks wait for rail, then 10s for workers |
| t=100 | SIGKILL if not exited |

> **Note:** If you increase `SPB_TAKE_BUDGET_SEC` or `SPB_PERSIST_TIMEOUT_SEC`, raise `terminationGracePeriodSeconds` accordingly. The default assumes 15s read budget and 60s persist timeout.

---

## Configuration Reference

### Full values.yaml structure

```yaml
nameOverride: ""
fullnameOverride: ""

jd-courier:
  image:
    repository: ghcr.io/lerianstudio/br-jd-courier
    tag: "1.0.0-rc.1"
    pullPolicy: IfNotPresent

imagePullSecrets: []

config:
  # Non-secret environment shared by all roles (rendered into ConfigMap)
  # Example single-tenant configuration:
  ENVIRONMENT_NAME: "production"
  PLUGIN_AUTH_ENABLED: "true"
  PLUGIN_AUTH_HOST: "http://access-manager.auth.svc.cluster.local"
  JD_BASE_URL: "https://jd-consultores.example.com"
  JD_SOAP_PATH: "/soap/spb"
  JD_LEGACY_CODE: "12345"
  JD_USER_CODE: "67890"
  SPB_VENDOR_TIMEOUT: "7s"
  SPB_TAKE_BUDGET_SEC: "15"
  SPB_PERSIST_TIMEOUT_SEC: "60"
  JD_ALLOW_PRIVATE_NETWORK: "false"
  # Multi-tenant example:
  # MULTI_TENANT_ENABLED: "true"
  # SYSTEMPLANE_ENABLED: "true"

secrets:
  existingSecret: ""  # Defaults to release fullname if empty

telemetry:
  otlpEndpoint: "$(NODE_IP):4317"

ports:
  http: 8080
  soap: 8081

roles:
  spbConsumer:
    enabled: true
    replicas: 1  # MUST be 1
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  spbSender:
    enabled: true
    replicas: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    service:
      type: ClusterIP
  pixIngress:
    enabled: true
    replicas: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    service:
      type: ClusterIP
  admin:
    enabled: true
    replicas: 1
    resources:
      requests:
        memory: "128Mi"
        cpu: "50m"
      limits:
        memory: "256Mi"
        cpu: "200m"
    service:
      type: ClusterIP

migrations:
  enabled: true
  backoffLimit: 3
  activeDeadlineSeconds: 600
  resources:
    requests:
      memory: "128Mi"
      cpu: "50m"
    limits:
      memory: "256Mi"
      cpu: "200m"

podAnnotations: {}
nodeSelector: {}
tolerations: []
affinity: {}
terminationGracePeriodSeconds: 100
```

### Key configuration flags

| Flag | Default | Description |
|------|---------|-------------|
| `jd-courier.image.tag` | `1.0.0-rc.1` (chart `appVersion`) | Container image tag (no leading `v`) |
| `secrets.existingSecret` | Release fullname | Name of pre-existing Secret with `LICENSE_KEY`, `DATABASE_URL`, etc. |
| `telemetry.otlpEndpoint` | `$(NODE_IP):4317` | OTLP collector address (node-local by default) |
| `ports.http` | `8080` | JSON/HTTP listener port (probes, admin, all roles) |
| `ports.soap` | `8081` | SOAP listener port (`spb-sender` only) |
| `roles.<role>.enabled` | `true` | Whether to deploy this role |
| `roles.<role>.replicas` | Varies (1 or 2) | Replica count (`spbConsumer` must be 1) |
| `roles.<role>.resources` | `{}` | Resource requests/limits for this role |
| `migrations.enabled` | `true` | Run pre-install/pre-upgrade migration Job (single-tenant only) |
| `terminationGracePeriodSeconds` | `100` | Grace period before SIGKILL (tuned for `spb-consumer` drain) |

### Required Secret keys

The Secret referenced by `secrets.existingSecret` must contain:

| Key | Required By | Description |
|-----|-------------|-------------|
| `LICENSE_KEY` | All roles | Application license (referenced by name in pod spec) |
| `DATABASE_URL` | Migration Job | Full database connection string |
| `POSTGRES_PASSWORD` | All roles (if using Postgres env vars) | Database password |
| `JD_PASSWORD` | SPB roles (single-tenant) | JD Consultores authentication |
| `REDIS_PASSWORD` | All roles (if Redis is used) | Redis password |
| `MULTI_TENANT_REDIS_PASSWORD` | All roles (multi-tenant) | Multi-tenant Redis password |
| `MULTI_TENANT_SERVICE_API_KEY` | All roles (multi-tenant) | Systemplane API key |

---

## Migration Steps

### Step 1: Create the required Secret

Before installing the chart, create a Secret with all required keys:

```bash
kubectl create secret generic br-jd-courier-secrets \
  --from-literal=LICENSE_KEY='your-license-key-here' \
  --from-literal=DATABASE_URL='postgresql://user:password@postgres.default.svc.cluster.local:5432/jd_courier' \
  --from-literal=POSTGRES_PASSWORD='your-db-password' \
  --from-literal=JD_PASSWORD='your-jd-password' \
  -n br-jd-courier
```

> **Important:** Adjust the keys based on your deployment mode (single-tenant vs. multi-tenant) and which optional features you use (Redis, etc.).

### Step 2: Prepare your values.yaml

Create a `values.yaml` with your configuration. **Example for single-tenant:**

```yaml
jd-courier:
  image:
    tag: "1.0.0-rc.1"

secrets:
  existingSecret: "br-jd-courier-secrets"

config:
  ENVIRONMENT_NAME: "production"
  PLUGIN_AUTH_ENABLED: "true"
  PLUGIN_AUTH_HOST: "http://access-manager.auth.svc.cluster.local"
  JD_BASE_URL: "https://jd-consultores.example.com"
  JD_SOAP_PATH: "/soap/spb"
  JD_LEGACY_CODE: "12345"
  JD_USER_CODE: "67890"
  SPB_VENDOR_TIMEOUT: "7s"
  SPB_TAKE_BUDGET_SEC: "15"
  SPB_PERSIST_TIMEOUT_SEC: "60"
  PIX_VENDOR_SUBJECTS: "CN=PixVendor,O=Example"

roles:
  spbConsumer:
    replicas: 1
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  spbSender:
    replicas: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  pixIngress:
    replicas: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  admin:
    replicas: 1
    resources:
      requests:
        memory: "128Mi"
        cpu: "50m"
      limits:
        memory: "256Mi"
        cpu: "200m"

migrations:
  enabled: true
```

**Example for multi-tenant:**

```yaml
jd-courier:
  image:
    tag: "1.0.0-rc.1"

secrets:
  existingSecret: "br-jd-courier-secrets"

config:
  ENVIRONMENT_NAME: "production"
  PLUGIN_AUTH_ENABLED: "true"
  PLUGIN_AUTH_HOST: "http://access-manager.auth.svc.cluster.local"
  MULTI_TENANT_ENABLED: "true"
  SYSTEMPLANE_ENABLED: "true"
  SPB_VENDOR_TIMEOUT: "7s"
  SPB_TAKE_BUDGET_SEC: "15"
  SPB_PERSIST_TIMEOUT_SEC: "60"

roles:
  spbConsumer:
    replicas: 1
  spbSender:
    replicas: 3
  pixIngress:
    replicas: 3
  admin:
    replicas: 1

migrations:
  enabled: false  # Multi-tenant migrations handled externally
```

### Step 3: Review the diff

Use the helm-diff plugin to preview changes:

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm \
  --version 1.0.0 \
  --values values.yaml \
  -n br-jd-courier
```

### Step 4: Perform the upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm \
  --install \
  --version 1.0.0 \
  --values values.yaml \
  -n br-jd-courier \
  --create-namespace
```

> **Note:** The `--install` flag allows this command to work for both new installs and upgrades. For a strict upgrade (fail if not already installed), omit `--install`.

### Step 5: Verify the deployment

Check that all roles are running:

```bash
kubectl get pods -n br-jd-courier -l app.kubernetes.io/name=br-jd-courier
```

Expected output (with default replica counts):

```
NAME                                      READY   STATUS    RESTARTS   AGE
br-jd-courier-spb-consumer-xxx            1/1     Running   0          2m
br-jd-courier-spb-sender-xxx              1/1     Running   0          2m
br-jd-courier-spb-sender-yyy              1/1     Running   0          2m
br-jd-courier-pix-ingress-xxx             1/1     Running   0          2m
br-jd-courier-pix-ingress-yyy             1/1     Running   0          2m
br-jd-courier-admin-xxx                   1/1     Running   0          2m
```

Check the migration Job (if enabled):

```bash
kubectl get jobs -n br-jd-courier -l app.kubernetes.io/component=migration
```

Verify Services:

```bash
kubectl get svc -n br-jd-courier
```

Expected Services: `br-jd-courier-spb-sender`, `br-jd-courier-pix-ingress`, `br-jd-courier-admin` (no Service for `spb-consumer`).

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 1.0.0 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 1.0.0 -n br-jd-courier
```
