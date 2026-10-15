# Helm Upgrade from v1.x to v2.x

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [ENVIRONMENT_NAME is now mandatory](#environment_name-is-now-mandatory)
  - [SOAP TLS configuration keys moved to dedicated values](#soap-tls-configuration-keys-moved-to-dedicated-values)
- **[Features](#features)**
  - [1. ServiceAccount support with AWS identity integration](#1-serviceaccount-support-with-aws-identity-integration)
  - [2. SOAP TLS configuration via dedicated values](#2-soap-tls-configuration-via-dedicated-values)
  - [3. SOAP Ingress support](#3-soap-ingress-support)
  - [4. DEPLOYMENT_MODE environment variable](#4-deployment_mode-environment-variable)
  - [5. Automatic OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT](#5-automatic-otel_resource_deployment_environment)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Breaking Changes

### ENVIRONMENT_NAME is now mandatory

| Setting | v1.0.1 | v2.0.0 |
|---------|---------|---------|
| `config.ENVIRONMENT_NAME` | Optional | **Mandatory** — chart refuses to render if unset |
| Boot behavior when unset | Service boots as `development` | Chart fails at render time |

**What changed:**

The chart now enforces that `config.ENVIRONMENT_NAME` must be set and non-empty (after trimming whitespace). Previously, the service would boot with a default of `development` if this variable was unset, which could lead to:
- Production checks being disabled
- Wrong environment segment in secret paths (e.g., `tenants/{env}/...` in multi-tenant mode)
- Incorrect credential references for Pix engines

**Why it matters:**

`ENVIRONMENT_NAME` controls critical production behavior:
- Enables production validation checks when set to `production`
- Forms the environment segment of every Pix engine `credentialRef` path
- Forms the environment segment of multi-tenant JD bundle paths (`tenants/{env}/...`)
- Without it, the service boots in `development` mode with relaxed checks and wrong secret paths

**Before (v1.0.1):**

```yaml
config:
  PLUGIN_AUTH_ENABLED: "true"
  # ENVIRONMENT_NAME was optional
```

**After (v2.0.0):**

```yaml
config:
  PLUGIN_AUTH_ENABLED: "true"
  ENVIRONMENT_NAME: "production"  # Now mandatory
```

**Migration action required:**

Add `ENVIRONMENT_NAME` to your `config` block in `values.yaml`:

```yaml
config:
  ENVIRONMENT_NAME: "production"
```

> **Important:** The chart trims whitespace from this value. An empty string after trimming will cause the chart to refuse to render with an error message explaining the requirement.

> **Note:** If you were previously using `ENV_NAME` (the service's deprecated alias), you must rename it to `ENVIRONMENT_NAME`. The chart does not accept `ENV_NAME` and will fail with a clear error message directing you to rename it.

**If you are currently running without ENVIRONMENT_NAME:**

Your service is running in `development` mode. Before upgrading to v2.0.0:

1. Verify your current environment name by checking your deployment's actual behavior
2. Add the correct value to your `values.yaml`
3. Upgrade — the chart will now enforce this at render time

### SOAP TLS configuration keys moved to dedicated values

| Setting | v1.0.1 | v2.0.0 |
|---------|---------|---------|
| `config.SOAP_TLS_CERT_FILE` | Allowed in `config` | **Refused** — use `roles.spbSender.soapTls.existingSecret` |
| `config.SOAP_TLS_KEY_FILE` | Allowed in `config` | **Refused** — use `roles.spbSender.soapTls.existingSecret` |
| `config.SOAP_TLS_TERMINATED_UPSTREAM` | Allowed in `config` | **Refused** — use `roles.spbSender.soapTls.terminatedUpstream` or `roles.spbSender.ingress.enabled` |
| SOAP TLS Secret mounting | Manual | Automatic when `soapTls.existingSecret` is set |
| Production boot check | None | `spb-sender` refuses to boot unless TLS is configured |

**What changed:**

The chart now manages SOAP TLS configuration through dedicated values blocks instead of allowing operators to set `SOAP_TLS_*` keys directly in `config`. The chart will refuse to render if any of these keys appear in `config`:

- `SOAP_TLS_CERT_FILE`
- `SOAP_TLS_KEY_FILE`
- `SOAP_TLS_TERMINATED_UPSTREAM`

Additionally, in production mode (`DEPLOYMENT_MODE: "byoc"` or `DEPLOYMENT_MODE: "saas"`), the `spb-sender` role now refuses to boot unless one of the following is configured:
- `roles.spbSender.soapTls.existingSecret` (TLS at the pod)
- `roles.spbSender.soapTls.terminatedUpstream: true` (TLS terminated externally)
- `roles.spbSender.ingress.enabled: true` (TLS at the Ingress)

**Why it matters:**

This change:
- Prevents operators from accidentally exposing the SOAP endpoint over plain HTTP in production
- Automates Secret mounting — the chart now handles the volume mount and environment variables
- Provides a clear, type-safe way to configure TLS termination location
- Enforces TLS in production deployments

**Before (v1.0.1):**

Operators had to manually set environment variables and mount Secrets:

```yaml
config:
  SOAP_TLS_CERT_FILE: "/etc/jd-courier/soap-tls/tls.crt"
  SOAP_TLS_KEY_FILE: "/etc/jd-courier/soap-tls/tls.key"
```

Then manually add volume mounts in a custom template or via `extraVolumes` (if supported).

**After (v2.0.0):**

The chart manages everything automatically:

```yaml
roles:
  spbSender:
    soapTls:
      existingSecret: "soap-tls-cert"
```

The chart automatically:
- Mounts the Secret at `/etc/jd-courier/soap-tls` (read-only)
- Sets `SOAP_TLS_CERT_FILE=/etc/jd-courier/soap-tls/tls.crt`
- Sets `SOAP_TLS_KEY_FILE=/etc/jd-courier/soap-tls/tls.key`

**Migration action required:**

Choose one of the following options based on your TLS termination strategy:

#### Option 1: TLS at the pod (existing Secret)

If you have a `kubernetes.io/tls` Secret with your certificate:

1. Remove `SOAP_TLS_CERT_FILE` and `SOAP_TLS_KEY_FILE` from `config`
2. Set `roles.spbSender.soapTls.existingSecret` to your Secret name:

```yaml
config:
  # Remove these:
  # SOAP_TLS_CERT_FILE: "/etc/jd-courier/soap-tls/tls.crt"
  # SOAP_TLS_KEY_FILE: "/etc/jd-courier/soap-tls/tls.key"

roles:
  spbSender:
    soapTls:
      existingSecret: "soap-tls-cert"
```

> **Note:** The Secret must be type `kubernetes.io/tls` with keys `tls.crt` and `tls.key`. The certificate is read once at boot — rotating it requires a rollout restart.

#### Option 2: TLS terminated upstream (service mesh, external load balancer)

If TLS is terminated before reaching the pod (e.g., by Istio, Linkerd, or an external load balancer):

1. Remove `SOAP_TLS_TERMINATED_UPSTREAM` from `config`
2. Set `roles.spbSender.soapTls.terminatedUpstream: true`:

```yaml
config:
  # Remove this:
  # SOAP_TLS_TERMINATED_UPSTREAM: "true"

roles:
  spbSender:
    soapTls:
      terminatedUpstream: true
```

The chart will set `SOAP_TLS_TERMINATED_UPSTREAM=true` automatically.

#### Option 3: TLS at the Ingress (new in v2.0.0)

If you want the chart to render an Ingress that terminates TLS:

```yaml
roles:
  spbSender:
    ingress:
      enabled: true
      className: "nginx"
      annotations:
        cert-manager.io/cluster-issuer: "letsencrypt-prod"
      hosts:
        - host: "soap.example.com"
          paths:
            - path: /
              pathType: Prefix
      tls:
        - secretName: soap-tls-cert
          hosts:
            - soap.example.com
```

The chart will automatically set `SOAP_TLS_TERMINATED_UPSTREAM=true` when `ingress.enabled: true`.

> **Warning:** In production (`DEPLOYMENT_MODE: "byoc"` or `DEPLOYMENT_MODE: "saas"`), the `spb-sender` will refuse to boot if none of these options are configured. In local mode (`DEPLOYMENT_MODE: "local"`), TLS is optional.

---

## Features

### 1. ServiceAccount support with AWS identity integration

| Setting | v1.0.1 | v2.0.0 |
|---------|---------|---------|
| ServiceAccount creation | Not supported | `serviceAccount.create` |
| ServiceAccount name | Always `default` | Configurable via `serviceAccount.name` |
| ServiceAccount annotations | Not supported | `serviceAccount.annotations` (for IRSA, EKS Pod Identity) |
| `automountServiceAccountToken` | `false` (hardcoded) | `false` (unchanged — Courier never calls Kubernetes API) |

**What changed:**

The chart now supports creating and configuring a ServiceAccount for all roles, with annotations for AWS identity integration (IRSA or EKS Pod Identity).

**New values:**

```yaml
serviceAccount:
  create: false
  name: ""
  annotations: {}
```

**New template:**

The chart now renders `templates/common/serviceaccount.yaml` when `serviceAccount.create: true`, and every Deployment references the ServiceAccount via the `br-jd-courier.serviceAccountName` helper.

**Why it matters:**

This enables:
- **AWS IRSA (IAM Roles for Service Accounts):** Annotate the ServiceAccount with `eks.amazonaws.com/role-arn` to grant AWS IAM permissions to the Courier pods
- **EKS Pod Identity:** Annotate with `eks.amazonaws.com/pod-identity-association` for the newer Pod Identity mechanism
- **Custom ServiceAccount names:** Use a pre-existing ServiceAccount managed outside the chart

**Default behavior:**

If `serviceAccount.create: false` and `serviceAccount.name: ""` (the defaults), every role uses the namespace's `default` ServiceAccount.

**Configuration examples:**

#### Create a ServiceAccount with IRSA annotation

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/jd-courier-role"
```

The chart will create a ServiceAccount named after the release (e.g., `br-jd-courier`) with the IRSA annotation, and all roles will use it.

#### Use a pre-existing ServiceAccount

```yaml
serviceAccount:
  create: false
  name: "jd-courier-sa"
```

All roles will use the `jd-courier-sa` ServiceAccount (which must already exist in the namespace).

#### Create a ServiceAccount with a custom name

```yaml
serviceAccount:
  create: true
  name: "custom-courier-sa"
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/jd-courier-role"
```

> **Note:** The Courier never calls the Kubernetes API, so `automountServiceAccountToken` remains `false`. IRSA and EKS Pod Identity inject their own projected tokens regardless of this field.

**New environment variables:**

None — AWS identity mechanisms work through ServiceAccount annotations and projected tokens, not environment variables.

### 2. SOAP TLS configuration via dedicated values

| Setting | v1.0.1 | v2.0.0 |
|---------|---------|---------|
| SOAP TLS Secret mounting | Manual | Automatic via `roles.spbSender.soapTls.existingSecret` |
| `SOAP_TLS_CERT_FILE` | Set manually in `config` | Set automatically by chart when `soapTls.existingSecret` is set |
| `SOAP_TLS_KEY_FILE` | Set manually in `config` | Set automatically by chart when `soapTls.existingSecret` is set |
| `SOAP_TLS_TERMINATED_UPSTREAM` | Set manually in `config` | Set automatically by chart when `soapTls.terminatedUpstream: true` or `ingress.enabled: true` |
| Production TLS enforcement | None | `spb-sender` refuses to boot without TLS in production mode |

**What changed:**

The chart now provides a dedicated `roles.spbSender.soapTls` block to configure TLS for the SOAP listener. This replaces manual configuration of `SOAP_TLS_*` environment variables in `config`.

**New values:**

```yaml
roles:
  spbSender:
    soapTls:
      existingSecret: ""
      terminatedUpstream: false
```

**How it works:**

When `soapTls.existingSecret` is set, the chart:
1. Mounts the Secret at `/etc/jd-courier/soap-tls` (read-only)
2. Sets `SOAP_TLS_CERT_FILE=/etc/jd-courier/soap-tls/tls.crt`
3. Sets `SOAP_TLS_KEY_FILE=/etc/jd-courier/soap-tls/tls.key`

When `soapTls.terminatedUpstream: true` or `ingress.enabled: true`, the chart sets `SOAP_TLS_TERMINATED_UPSTREAM=true`.

**Why it matters:**

- **Automation:** No need to manually configure volume mounts or environment variables
- **Type safety:** The chart validates that the Secret exists (at render time, if using strict mode)
- **Production safety:** In production mode, the `spb-sender` refuses to boot unless TLS is configured
- **Certificate rotation:** The certificate is read once at boot, so rotating it requires a rollout restart (this is now documented in the values comments)

**Configuration examples:**

#### TLS with a kubernetes.io/tls Secret

```yaml
roles:
  spbSender:
    soapTls:
      existingSecret: "soap-tls-cert"
```

The Secret must have keys `tls.crt` and `tls.key`:

```bash
kubectl create secret tls soap-tls-cert \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n br-jd-courier
```

#### TLS terminated by a service mesh

```yaml
roles:
  spbSender:
    soapTls:
      terminatedUpstream: true
```

The chart sets `SOAP_TLS_TERMINATED_UPSTREAM=true`, and the `spb-sender` expects TLS to be terminated before reaching the pod.

> **Important:** The certificate is read once at boot. To rotate it, update the Secret and then perform a rollout restart:

```bash
kubectl rollout restart deployment/br-jd-courier-spb-sender -n br-jd-courier
```

**New environment variables set by the chart:**

| Variable | Set When | Value |
|----------|----------|-------|
| `SOAP_TLS_CERT_FILE` | `soapTls.existingSecret` is set | `/etc/jd-courier/soap-tls/tls.crt` |
| `SOAP_TLS_KEY_FILE` | `soapTls.existingSecret` is set | `/etc/jd-courier/soap-tls/tls.key` |
| `SOAP_TLS_TERMINATED_UPSTREAM` | `soapTls.terminatedUpstream: true` or `ingress.enabled: true` | `true` |

### 3. SOAP Ingress support

| Setting | v1.0.1 | v2.0.0 |
|---------|---------|---------|
| SOAP Ingress | Not supported | `roles.spbSender.ingress` |
| Ingress class | N/A | `roles.spbSender.ingress.className` |
| Ingress annotations | N/A | `roles.spbSender.ingress.annotations` |
| TLS configuration | N/A | `roles.spbSender.ingress.tls` |

**What changed:**

The chart now renders an Ingress resource for the `spb-sender` role's SOAP Service when `roles.spbSender.ingress.enabled: true`. This routes external traffic to the SOAP listener and terminates TLS at the Ingress.

**New template:**

`templates/spb-sender/ingress.yaml` is rendered when both `roles.spbSender.enabled: true` and `roles.spbSender.ingress.enabled: true`.

**New values:**

```yaml
roles:
  spbSender:
    ingress:
      enabled: false
      className: ""
      annotations: {}
      hosts:
        - host: ""
          paths:
            - path: /
              pathType: Prefix
      tls: []
```

**Why it matters:**

- **External SOAP access:** Exposes the SOAP listener to external clients (JD Consultores, SPB vendors)
- **TLS termination:** The Ingress terminates TLS, and the chart automatically sets `SOAP_TLS_TERMINATED_UPSTREAM=true`
- **AWS integration:** Supports AWS-specific annotations for ALB health checks and target group settings (see examples below)

**Configuration examples:**

#### Basic Ingress with cert-manager

```yaml
roles:
  spbSender:
    ingress:
      enabled: true
      className: "nginx"
      annotations:
        cert-manager.io/cluster-issuer: "letsencrypt-prod"
      hosts:
        - host: "soap.example.com"
          paths:
            - path: /
              pathType: Prefix
      tls:
        - secretName: soap-tls-cert
          hosts:
            - soap.example.com
```

#### AWS ALB with health check annotations

```yaml
roles:
  spbSender:
    ingress:
      enabled: true
      className: "alb"
      annotations:
        alb.ingress.kubernetes.io/scheme: "internet-facing"
        alb.ingress.kubernetes.io/target-type: "ip"
        alb.ingress.kubernetes.io/healthcheck-path: "/health"
        alb.ingress.kubernetes.io/healthcheck-port: "8080"
        alb.ingress.kubernetes.io/healthcheck-protocol: "HTTP"
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
        alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/abc123"
      hosts:
        - host: "soap.example.com"
          paths:
            - path: /
              pathType: Prefix
```

> **Note:** When `ingress.enabled: true`, the chart automatically sets `SOAP_TLS_TERMINATED_UPSTREAM=true`. The `spb-sender` will expect TLS to be terminated at the Ingress.

> **Important:** The Ingress routes to the `spb-sender` Service on the `soap` port (default: 8081). Ensure your Ingress controller can reach the Service.

**Health check considerations:**

The SOAP listener does not expose a health endpoint. For AWS ALB, configure the health check to use the HTTP listener (port 8080, path `/health`) instead of the SOAP port:

```yaml
annotations:
  alb.ingress.kubernetes.io/healthcheck-path: "/health"
  alb.ingress.kubernetes.io/healthcheck-port: "8080"
  alb.ingress.kubernetes.io/healthcheck-protocol: "HTTP"
```

### 4. DEPLOYMENT_MODE environment variable

| Setting | v1.0.1 | v2.0.0 |
|---------|---------|---------|
| `config.DEPLOYMENT_MODE` | Not present | New, default: `"byoc"` |
| Production TLS checks | None | Enforced when `DEPLOYMENT_MODE: "saas"` |

**What changed:**

The chart now sets `DEPLOYMENT_MODE` in the default `config` block, with a default value of `"byoc"` (Bring Your Own Cloud).

**New default in values.yaml:**

```yaml
config:
  PLUGIN_AUTH_ENABLED: "true"
  DEPLOYMENT_MODE: "byoc"
```

**Why it matters:**

`DEPLOYMENT_MODE` controls production validation checks in the application:

| Mode | Description | TLS Enforcement |
|------|-------------|-----------------|
| `local` | Local development | No TLS checks |
| `byoc` | Customer-managed cloud (default) | No TLS checks (assumes customer handles TLS) |
| `saas` | Lerian-managed SaaS | **Strict:** Refuses to boot unless every datastore connection is TLS |

In `saas` mode, the application enforces that:
- All database connections use TLS
- All Redis connections use TLS
- The SOAP listener has TLS configured (via `soapTls.existingSecret`, `soapTls.terminatedUpstream`, or `ingress.enabled`)

**Migration action:**

If you are running a SaaS deployment where Lerian manages the infrastructure, set:

```yaml
config:
  DEPLOYMENT_MODE: "saas"
```

If you are running in a customer-managed cloud (the default), leave it as `"byoc"` or omit it (the chart defaults to `"byoc"`).

If you are running locally for development, set:

```yaml
config:
  DEPLOYMENT_MODE: "local"
```

> **Warning:** In `saas` mode, the `spb-sender` will refuse to boot unless TLS is configured for the SOAP listener. Ensure you have set one of `roles.spbSender.soapTls.existingSecret`, `roles.spbSender.soapTls.terminatedUpstream: true`, or `roles.spbSender.ingress.enabled: true`.

### 5. Automatic OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT

| Setting | v1.0.1 | v2.0.0 |
|---------|---------|---------|
| `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | Not set | Automatically set to `ENVIRONMENT_NAME` unless overridden |

**What changed:**

The chart now automatically sets `OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` to match `ENVIRONMENT_NAME` (after trimming whitespace) unless you explicitly set it in `config`.

**Template logic:**

In `templates/common/configmap.yaml`:

```yaml
{{- if not (hasKey . "OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT") }}
OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: {{ get . "ENVIRONMENT_NAME" | toString | trim | quote }}
{{- end }}
```

**Why it matters:**

OpenTelemetry resource attributes should include the deployment environment for proper trace and metric segmentation. Previously, operators had to set this manually. Now it follows `ENVIRONMENT_NAME` automatically.

**Default behavior:**

If you set:

```yaml
config:
  ENVIRONMENT_NAME: "production"
```

The chart automatically sets:

```yaml
OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "production"
```

**To override:**

If you want a different value for the OTEL resource attribute:

```yaml
config:
  ENVIRONMENT_NAME: "production"
  OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT: "prod-us-east-1"
```

> **Note:** This is purely for telemetry metadata. It does not affect the Courier's production checks or secret paths (those use `ENVIRONMENT_NAME`).

---

## Configuration Reference

### New values in v2.0.0

#### ServiceAccount

```yaml
serviceAccount:
  create: false
  name: ""
  annotations: {}
```

| Flag | Default | Description |
|------|---------|-------------|
| `serviceAccount.create` | `false` | Whether to create a ServiceAccount for all roles |
| `serviceAccount.name` | `""` | ServiceAccount name (defaults to release fullname if `create: true`, or `default` if `create: false`) |
| `serviceAccount.annotations` | `{}` | Annotations for the ServiceAccount (e.g., `eks.amazonaws.com/role-arn` for IRSA) |

#### SOAP TLS configuration

```yaml
roles:
  spbSender:
    soapTls:
      existingSecret: ""
      terminatedUpstream: false
```

| Flag | Default | Description |
|------|---------|-------------|
| `roles.spbSender.soapTls.existingSecret` | `""` | Name of a `kubernetes.io/tls` Secret (keys: `tls.crt`, `tls.key`) mounted at `/etc/jd-courier/soap-tls` |
| `roles.spbSender.soapTls.terminatedUpstream` | `false` | TLS is terminated before the pod (e.g., by a service mesh or external load balancer) |

#### SOAP Ingress

```yaml
roles:
  spbSender:
    ingress:
      enabled: false
      className: ""
      annotations: {}
      hosts:
        - host: ""
          paths:
            - path: /
              pathType: Prefix
      tls: []
```

| Flag | Default | Description |
|------|---------|-------------|
| `roles.spbSender.ingress.enabled` | `false` | Whether to create an Ingress for the SOAP Service |
| `roles.spbSender.ingress.className` | `""` | Ingress class name (e.g., `nginx`, `alb`) |
| `roles.spbSender.ingress.annotations` | `{}` | Ingress annotations (e.g., cert-manager, ALB settings) |
| `roles.spbSender.ingress.hosts` | `[]` | List of hosts and paths to route to the SOAP Service |
| `roles.spbSender.ingress.tls` | `[]` | TLS configuration for the Ingress |

#### New config defaults

```yaml
config:
  PLUGIN_AUTH_ENABLED: "true"
  DEPLOYMENT_MODE: "byoc"
```

| Flag | Default | Description |
|------|---------|-------------|
| `config.ENVIRONMENT_NAME` | **(mandatory)** | Environment name (e.g., `production`, `staging`) — chart refuses to render if unset |
| `config.DEPLOYMENT_MODE` | `"byoc"` | Deployment mode: `local` (no production checks), `byoc` (customer-managed), or `saas` (strict TLS enforcement) |
| `config.OTEL_RESOURCE_DEPLOYMENT_ENVIRONMENT` | Follows `ENVIRONMENT_NAME` | OpenTelemetry resource attribute for deployment environment (auto-set unless overridden) |

### Full example values.yaml for v2.0.0

#### Single-tenant with SOAP TLS at the pod

```yaml
jd-courier:
  image:
    tag: "1.1.0"

serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/jd-courier-role"

secrets:
  existingSecret: "br-jd-courier-secrets"

config:
  ENVIRONMENT_NAME: "production"
  DEPLOYMENT_MODE: "byoc"
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
    soapTls:
      existingSecret: "soap-tls-cert"
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

#### Single-tenant with SOAP Ingress (TLS at Ingress)

```yaml
jd-courier:
  image:
    tag: "1.1.0"

serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/jd-courier-role"

secrets:
  existingSecret: "br-jd-courier-secrets"

config:
  ENVIRONMENT_NAME: "production"
  DEPLOYMENT_MODE: "byoc"
  PLUGIN_AUTH_ENABLED: "true"
  PLUGIN_AUTH_HOST: "http://access-manager.auth.svc.cluster.local"
  JD_BASE_URL: "https://jd-consultores.example.com"
  JD_SOAP_PATH: "/soap/spb"
  JD_LEGACY_CODE: "12345"
  JD_USER_CODE: "67890"
  SPB_VENDOR_TIMEOUT: "7s"
  PIX_VENDOR_SUBJECTS: "CN=PixVendor,O=Example"

roles:
  spbConsumer:
    replicas: 1
  spbSender:
    replicas: 2
    ingress:
      enabled: true
      className: "nginx"
      annotations:
        cert-manager.io/cluster-issuer: "letsencrypt-prod"
      hosts:
        - host: "soap.example.com"
          paths:
            - path: /
              pathType: Prefix
      tls:
        - secretName: soap-tls-cert
          hosts:
            - soap.example.com
  pixIngress:
    replicas: 2
  admin:
    replicas: 1

migrations:
  enabled: true
```

#### Multi-tenant with SOAP TLS terminated upstream

```yaml
jd-courier:
  image:
    tag: "1.1.0"
