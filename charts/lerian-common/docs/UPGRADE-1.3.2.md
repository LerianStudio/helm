# Helm Upgrade from v1.3.1 to v1.3.2

## Topics ToC

- **[Fixes](#fixes)**
  - [1. Service Discovery Default Address](#1-service-discovery-default-address)
  - [2. Ingress Class Name Override](#2-ingress-class-name-override)
  - [3. Multi-Tenant Circuit Breaker Zero-Value Handling](#3-multi-tenant-circuit-breaker-zero-value-handling)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Service Discovery Default Address

The `lerian-common.serviceDiscovery.env` helper now provides a default value for `SD_ADDRESS` when service discovery is enabled but no address is explicitly configured.

#### What changed

| Setting | v1.3.1 | v1.3.2 |
|---------|---------|---------|
| `SD_ADDRESS` default | No default (empty string) | `localhost:8500` |

**Before (v1.3.1):**

When `SD_ENABLED=true` but neither `global.serviceDiscovery.address` nor `configmap.SD_ADDRESS` was set, the helper would emit an empty `SD_ADDRESS`, causing service discovery clients to fail at runtime.

**After (v1.3.2):**

When `SD_ENABLED=true` and no address is configured, `SD_ADDRESS` defaults to `localhost:8500`, matching the behavior of pre-productization charts where enabling SD alone (without explicit configuration) still rendered a functional SD_* contract.

#### Why it matters

This fix ensures that enabling service discovery (`SD_ENABLED=true`) produces a valid configuration even when operators have not yet migrated to the `global.serviceDiscovery` contract or set a legacy `configmap.SD_ADDRESS`. The default `localhost:8500` allows local development and testing scenarios to work without explicit configuration.

#### Operational impact

**For production deployments:**

No action required if you are already setting `global.serviceDiscovery.address` or `configmap.SD_ADDRESS`. The precedence remains unchanged:

```yaml
# Precedence (highest to lowest):
# 1. Component-level configmap.SD_ADDRESS
# 2. global.serviceDiscovery.address
# 3. Default: localhost:8500 (new in v1.3.2)
```

**For development/testing deployments:**

If you were previously setting `SD_ENABLED=true` without an address and experiencing runtime failures, this fix resolves the issue. The helper now emits:

```yaml
SD_ENABLED: "true"
SD_ADDRESS: "localhost:8500"
```

> **Important:** The `localhost:8500` default is intended for local development. Production deployments should always set `global.serviceDiscovery.address` to point to the actual Consul cluster.

**Configuration example (production):**

```yaml
global:
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    tls: true
    tlsSkipVerify: false
    workload: "production"
```

### 2. Ingress Class Name Override

The `lerian-common.ingress` helper now correctly honors an explicit empty `className` at the component level instead of falling back to the global class.

#### What changed

| Setting | v1.3.1 | v1.3.2 |
|---------|---------|---------|
| Component `className: ""` behavior | Falls back to `global.className` | Honored (no class emitted) |

**Before (v1.3.1):**

```yaml
# values.yaml
global:
  className: "nginx"

myapp:
  ingress:
    className: ""  # Operator wants NO class for this ingress
```

The helper would ignore the explicit empty string and emit `ingressClassName: nginx` (from global), preventing operators from deliberately omitting the class.

**After (v1.3.2):**

```yaml
# values.yaml
global:
  className: "nginx"

myapp:
  ingress:
    className: ""  # Operator wants NO class for this ingress
```

The helper now uses presence-based detection (`hasKey`) instead of truthiness. An explicit `className: ""` at the component level is honored, and no `ingressClassName` field is emitted in the Ingress resource.

#### Why it matters

Some Kubernetes clusters use a default IngressClass (marked with `ingressclass.kubernetes.io/is-default-class: "true"`). In these environments, operators may want to omit the `ingressClassName` field entirely to let the cluster default apply, rather than explicitly setting a class name.

The v1.3.1 behavior prevented this: setting `className: ""` would still emit the global class. Operators had no way to opt out of the class field when a global default was set.

#### Operational impact

**For most deployments:**

No action required. If you are not explicitly setting `className: ""` at the component level, behavior is unchanged.

**For deployments that need to omit the class:**

You can now explicitly set `className: ""` in a component's ingress configuration to prevent the global class from being applied:

```yaml
global:
  className: "nginx"

myapp:
  ingress:
    enabled: true
    className: ""  # Deliberately omit ingressClassName field
    hosts:
      - host: myapp.example.com
        paths:
          - path: /
            pathType: Prefix
```

**Rendered output (v1.3.2):**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
spec:
  # No ingressClassName field emitted
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp
                port:
                  number: 8080
```

> **Note:** Setting `className: ""` is different from omitting the `className` key entirely. Omitting the key will still fall back to the global class (if set). Setting `className: ""` explicitly opts out of the class field.

**Precedence (v1.3.2):**

```yaml
# Precedence (highest to lowest):
# 1. Component-level ingress.className (including explicit "")
# 2. global.className
# 3. No class emitted (if neither is set)
```

### 3. Multi-Tenant Circuit Breaker Zero-Value Handling

The `lerian-common.multiTenant.env` helper now correctly handles zero values (`0`, `"0"`) for circuit breaker, pool, and cache tuning parameters instead of falling back to defaults.

#### What changed

| Parameter | v1.3.1 behavior with `0` | v1.3.2 behavior with `0` |
|-----------|--------------------------|--------------------------|
| `MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD` | Falls back to `"5"` | Emits `"0"` |
| `MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC` | Falls back to `"30"` | Emits `"0"` |
| `MULTI_TENANT_MAX_TENANT_POOLS` | Falls back to `"100"` | Emits `"0"` |
| `MULTI_TENANT_IDLE_TIMEOUT_SEC` | Falls back to `"300"` | Emits `"0"` |
| `MULTI_TENANT_TIMEOUT` | Falls back to `"30"` | Emits `"0"` |
| `MULTI_TENANT_CACHE_TTL_SEC` | Falls back to `"120"` | Emits `"0"` |
| `MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC` | Falls back to `"30"` | Emits `"0"` |

**Before (v1.3.1):**

The helper used Sprig's `default` function, which treats `0`, `false`, and `""` as "empty" and falls back to the default value. This prevented operators from explicitly setting a parameter to zero (e.g., to disable a feature or remove a timeout).

```yaml
# values.yaml (v1.3.1)
myapp:
  configmap:
    MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "0"  # Operator wants to disable circuit breaker
```

**Rendered output (v1.3.1):**

```yaml
MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "5"  # Falls back to default, ignoring the explicit 0
```

**After (v1.3.2):**

The helper now uses presence-based detection (`hasKey`) instead of truthiness. An explicit `0` value is honored.

```yaml
# values.yaml (v1.3.2)
myapp:
  configmap:
    MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "0"  # Operator wants to disable circuit breaker
```

**Rendered output (v1.3.2):**

```yaml
MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "0"  # Explicit 0 is honored
```

#### Why it matters

Zero is a valid and meaningful value for many multi-tenant tuning parameters:

- `MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "0"` — Disable circuit breaker entirely
- `MULTI_TENANT_CACHE_TTL_SEC: "0"` — Disable caching
- `MULTI_TENANT_IDLE_TIMEOUT_SEC: "0"` — No idle timeout (connections never expire)

The v1.3.1 behavior prevented operators from setting these values to zero, forcing them to use the hardcoded defaults even when zero was the desired configuration.

#### Operational impact

**For most deployments:**

No action required. If you are not explicitly setting any of these parameters to `0`, behavior is unchanged. The defaults remain the same:

| Parameter | Default |
|-----------|---------|
| `MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD` | `"5"` |
| `MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC` | `"30"` |
| `MULTI_TENANT_MAX_TENANT_POOLS` | `"100"` |
| `MULTI_TENANT_IDLE_TIMEOUT_SEC` | `"300"` |
| `MULTI_TENANT_TIMEOUT` | `"30"` |
| `MULTI_TENANT_CACHE_TTL_SEC` | `"120"` |
| `MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC` | `"30"` |

**For deployments that need zero values:**

You can now explicitly set any of these parameters to `0` (as a string or integer) and the helper will honor it:

```yaml
# values.yaml
myapp:
  configmap:
    MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "0"  # Disable circuit breaker
    MULTI_TENANT_CACHE_TTL_SEC: "0"              # Disable caching
    MULTI_TENANT_IDLE_TIMEOUT_SEC: "0"           # No idle timeout
```

**Rendered output (v1.3.2):**

```yaml
MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD: "0"
MULTI_TENANT_CACHE_TTL_SEC: "0"
MULTI_TENANT_IDLE_TIMEOUT_SEC: "0"
```

> **Important:** Setting a parameter to `0` may have significant operational implications (e.g., disabling circuit breakers, removing timeouts). Consult the multi-tenant library documentation to understand the behavior of zero values for each parameter.

**Affected parameters:**

The following parameters now support explicit zero values:

- `MULTI_TENANT_CIRCUIT_BREAKER_THRESHOLD`
- `MULTI_TENANT_CIRCUIT_BREAKER_TIMEOUT_SEC`
- `MULTI_TENANT_MAX_TENANT_POOLS`
- `MULTI_TENANT_IDLE_TIMEOUT_SEC`
- `MULTI_TENANT_TIMEOUT`
- `MULTI_TENANT_CACHE_TTL_SEC`
- `MULTI_TENANT_CONNECTIONS_CHECK_INTERVAL_SEC`

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.2 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading to v1.3.2, run `helm diff` on the **product charts** that consume it after updating their `lerian-common` dependency to v1.3.2.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.2 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `1.3.2` and run `helm dependency update`, then upgrade the parent chart.
