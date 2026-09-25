# Helm Upgrade from v1.1.0 to v1.2.0

## Topics

- **[Overview](#overview)**
- **[Service Discovery Default Changes](#service-discovery-default-changes)**
  - [1. TLS Skip Verify Default](#1-tls-skip-verify-default)
  - [2. Prefer View Default](#2-prefer-view-default)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v1.2.0 updates **default values** for two service discovery environment variables emitted by the `lerian-common.serviceDiscovery.env` helper. These changes affect the behavior of components that rely on service discovery when operators have **not** explicitly set these fields in their values.

**What changed:**

- `SD_TLS_SKIP_VERIFY` default changed from `false` to `true`
- `SD_PREFER_VIEW` default changed from `external` to `internal`

**Who is affected:**

- Operators using service discovery (`global.serviceDiscovery.address` is set) **without** explicitly setting `tlsSkipVerify` or `preferView` in their values
- Components that consume the `lerian-common.serviceDiscovery.env` helper and rely on default values

**Backward compatibility:**

If you have explicitly set `global.serviceDiscovery.tlsSkipVerify` or `global.serviceDiscovery.preferView` in your umbrella `values.yaml`, **no change in behavior will occur**. The helper respects explicit configuration over defaults.

## Service Discovery Default Changes

### 1. TLS Skip Verify Default

The default value for `SD_TLS_SKIP_VERIFY` has changed to improve compatibility with development and internal environments.

| Setting | v1.1.0 | v1.2.0 |
|---------|---------|---------|
| `SD_TLS_SKIP_VERIFY` default | `false` | `true` |

#### What changed

The `lerian-common.serviceDiscovery.env` helper now emits `SD_TLS_SKIP_VERIFY: "true"` by default when `global.serviceDiscovery.tlsSkipVerify` is not explicitly set.

**Before (v1.1.0):**

```yaml
# Rendered ConfigMap (when global.serviceDiscovery.tlsSkipVerify is unset)
data:
  SD_TLS_SKIP_VERIFY: "false"
```

**After (v1.2.0):**

```yaml
# Rendered ConfigMap (when global.serviceDiscovery.tlsSkipVerify is unset)
data:
  SD_TLS_SKIP_VERIFY: "true"
```

#### Why it matters

**Security consideration:** Setting `SD_TLS_SKIP_VERIFY: "true"` disables TLS certificate verification for service discovery connections. This is appropriate for:

- Development and staging environments with self-signed certificates
- Internal service discovery servers without public CA-signed certificates
- Environments where certificate validation is handled at the infrastructure level (e.g. service mesh)

**Production environments** should explicitly set `tlsSkipVerify: false` to enforce certificate validation.

#### Operational impact

If you are running service discovery with TLS enabled (`global.serviceDiscovery.tls: true`) and rely on the default `tlsSkipVerify` behavior:

- **v1.1.0 behavior:** Components verified TLS certificates by default
- **v1.2.0 behavior:** Components skip TLS certificate verification by default

**Action required for production environments:**

If you require TLS certificate verification (recommended for production), explicitly set `tlsSkipVerify: false` in your umbrella `values.yaml`:

```yaml
global:
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    tls: true
    tlsSkipVerify: false  # Explicitly enforce certificate verification
```

> **Important:** If you do not set `tlsSkipVerify` explicitly and your service discovery server uses TLS with a certificate that would fail validation (e.g. self-signed, expired, hostname mismatch), components will now connect successfully instead of failing. Review your service discovery TLS configuration before upgrading.

### 2. Prefer View Default

The default value for `SD_PREFER_VIEW` has changed to optimize for in-cluster service resolution.

| Setting | v1.1.0 | v1.2.0 |
|---------|---------|---------|
| `SD_PREFER_VIEW` default | `external` | `internal` |

#### What changed

The `lerian-common.serviceDiscovery.env` helper now emits `SD_PREFER_VIEW: "internal"` by default when `global.serviceDiscovery.preferView` is not explicitly set.

**Before (v1.1.0):**

```yaml
# Rendered ConfigMap (when global.serviceDiscovery.preferView is unset)
data:
  SD_PREFER_VIEW: "external"
```

**After (v1.2.0):**

```yaml
# Rendered ConfigMap (when global.serviceDiscovery.preferView is unset)
data:
  SD_PREFER_VIEW: "internal"
```

#### Why it matters

The `SD_PREFER_VIEW` setting controls which service address the **lib-service-discovery** client prefers when resolving service endpoints:

- **`internal`:** Prefer cluster-internal addresses (e.g. `service.namespace.svc.cluster.local`)
- **`external`:** Prefer external addresses (e.g. ingress hostnames, load balancer IPs)

**Use cases:**

- **`internal` (new default):** Optimized for in-cluster communication (lower latency, no egress costs, no ingress traversal)
- **`external`:** Required when services must communicate via ingress (e.g. multi-cluster, hybrid cloud, external consumers)

#### Operational impact

If you rely on the default `preferView` behavior:

- **v1.1.0 behavior:** Components preferred external service addresses (ingress) by default
- **v1.2.0 behavior:** Components prefer internal service addresses (cluster DNS) by default

**Action required if you need external view:**

If your architecture requires services to communicate via ingress (e.g. multi-cluster setup, external load balancers), explicitly set `preferView: external` in your umbrella `values.yaml`:

```yaml
global:
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    preferView: external  # Explicitly prefer ingress addresses
```

> **Note:** The `preferView` setting is a **preference**, not a strict requirement. If the preferred view is unavailable, the service discovery client will fall back to the other view. This change primarily affects the **first choice** for service resolution.

## Configuration Reference

The following table shows the updated default values for service discovery configuration:

| Field | v1.1.0 Default | v1.2.0 Default | Description |
|-------|----------------|----------------|-------------|
| `global.serviceDiscovery.tlsSkipVerify` | `false` | `true` | Skip TLS certificate verification for service discovery connections |
| `global.serviceDiscovery.preferView` | `external` | `internal` | Preferred view for service resolution (`internal` or `external`) |

**Full service discovery configuration block (umbrella `values.yaml`):**

```yaml
global:
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    tls: true
    tlsSkipVerify: false  # Set explicitly for production (new default: true)
    workload: "production"
    preferView: external  # Set explicitly if external view required (new default: internal)
    internalScheme: http
    externalPort: 443
```

> **Important:** These defaults only apply when the corresponding field is **not set** in your values. Explicit configuration always takes precedence over defaults.

## Migration Steps

### For Operators (Umbrella Deployments)

If you manage Lerian product charts via an umbrella chart and use service discovery:

1. **Review your current service discovery configuration** in your umbrella `values.yaml`:

```bash
grep -A 10 "serviceDiscovery:" values.yaml
```

2. **Determine if you need to set explicit values:**

   - **For production environments with TLS:** Set `tlsSkipVerify: false` explicitly
   - **For multi-cluster or ingress-based communication:** Set `preferView: external` explicitly

3. **Update your umbrella `values.yaml` if needed:**

```yaml
global:
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    tls: true
    tlsSkipVerify: false  # Add this line for production
    preferView: external  # Add this line if external view required
```

4. **Preview the changes** (see [Preview changes before upgrading](#preview-changes-before-upgrading))

5. **Upgrade the umbrella chart:**

```bash
helm upgrade my-umbrella . -n lerian --values values.yaml
```

6. **Verify service discovery behavior** after upgrade:

   - Check that services can resolve each other via service discovery
   - Monitor logs for TLS certificate errors (if `tlsSkipVerify` was implicitly `false` before)
   - Verify that services use the expected view (internal vs external)

### For Standalone Deployments

If you deploy a single product chart without an umbrella:

1. **Check if the product chart has adopted `lerian-common` v1.2.0** (review the product chart's `Chart.yaml` dependencies)

2. **If the product chart uses service discovery**, review your component-level configuration:

```yaml
myapp:
  configmap:
    SD_TLS_SKIP_VERIFY: "false"  # Component-level override (takes precedence)
    SD_PREFER_VIEW: "external"   # Component-level override (takes precedence)
```

> **Note:** Component-level `configmap.*` values always take precedence over `global.serviceDiscovery.*` defaults. If you have set these values at the component level, no change in behavior will occur.

### For Chart Maintainers (Product Charts)

If you maintain a Lerian product chart that consumes `lerian-common`:

1. **Update the `lerian-common` dependency** in your product chart's `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common-helm
    version: 1.2.0
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Test the default behavior change** with your product chart:

```bash
helm template my-chart . --values test-values.yaml | grep -A 2 "SD_TLS_SKIP_VERIFY\|SD_PREFER_VIEW"
```

4. **Document the change** in your product chart's release notes if the default behavior change affects your users

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.2.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading to v1.2.0, run `helm diff` on the **product charts** or **umbrella chart** that consume it.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.2.0 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `1.2.0` and run `helm dependency update`, then upgrade the consuming chart.
