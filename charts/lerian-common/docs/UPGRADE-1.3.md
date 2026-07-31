# Helm Upgrade from v1.2.2 to v1.3.0

## Topics ToC

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Service Discovery Legacy Activation](#1-service-discovery-legacy-activation)
  - [2. Improved Precedence Logic](#2-improved-precedence-logic)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v1.3.0 enhances the Service Discovery helper (`lerian-common.serviceDiscovery.env`) with **legacy activation support** and **improved precedence logic** for component-level overrides.

**What changed:**

- The Service Discovery helper now activates from **either** `global.serviceDiscovery.address` (environment-wide) **or** `configmap.SD_ADDRESS` (legacy per-component)
- Precedence logic for all `SD_*` environment variables now uses **presence-based** resolution instead of truthiness-based, fixing a bug where explicit empty/false/0 values in `configmap.SD_*` were incorrectly overridden by global defaults

**Why it matters:**

- **Backward compatibility for on-prem/client deployments:** Charts deployed with legacy `configmap.SD_ENABLED=true` + `configmap.SD_ADDRESS` (no `global.serviceDiscovery` block) now correctly derive the full `SD_*` environment variable block, matching pre-refactor behavior
- **Correct override semantics:** Operators can now explicitly set `configmap.SD_TLS=false` or `configmap.SD_WORKLOAD=""` to override global defaults, instead of those values being ignored

**Who should upgrade:**

- Operators managing on-prem or client-specific deployments that use legacy `configmap.SD_*` values without `global.serviceDiscovery`
- Operators who need to override global Service Discovery settings with explicit empty or false values at the component level

**Operational impact:**

This is a **non-breaking enhancement**. Existing deployments continue to work unchanged:

- Deployments using `global.serviceDiscovery.address` (environment-wide) are unaffected
- Deployments using legacy `configmap.SD_ADDRESS` now correctly activate the helper (previously required `global.serviceDiscovery.address`)
- Deployments with no Service Discovery configuration remain inert

## Features

### 1. Service Discovery Legacy Activation

The `lerian-common.serviceDiscovery.env` helper now activates from **either** the environment-wide `global.serviceDiscovery.address` **or** the legacy per-component `configmap.SD_ADDRESS`.

#### What changed

**Before (v1.2.2):**

The helper only activated when **both** conditions were met:

1. Component had `SD_ENABLED=true` (via `configmap.SD_ENABLED` or `extraEnvVars`)
2. `global.serviceDiscovery.address` was configured

This meant legacy deployments with `configmap.SD_ENABLED=true` + `configmap.SD_ADDRESS` (no `global.serviceDiscovery` block) would **not** derive the full `SD_*` environment variable block, breaking backward compatibility with pre-refactor behavior.

**After (v1.3.0):**

The helper activates when **both** conditions are met:

1. Component has `SD_ENABLED=true`
2. **Either** `global.serviceDiscovery.address` **or** `configmap.SD_ADDRESS` is present

| Activation Condition | v1.2.2 | v1.3.0 |
|---------------------|---------|---------|
| `SD_ENABLED=true` + `global.serviceDiscovery.address` | ✅ Activates | ✅ Activates |
| `SD_ENABLED=true` + `configmap.SD_ADDRESS` | ❌ Does not activate | ✅ Activates |
| `SD_ENABLED=true` + neither address | ❌ Does not activate | ❌ Does not activate |

#### Why it matters

**On-prem and client-specific deployments** often use legacy `configmap.SD_*` values instead of the environment-wide `global.serviceDiscovery` block. Before v1.3.0, these deployments would not derive the full `SD_*` environment variable block, requiring operators to manually set every `SD_*` variable in `extraEnvVars`.

With v1.3.0, legacy deployments work correctly without migration.

#### Configuration example

**Legacy deployment (on-prem, no global block):**

```yaml
myapp:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.client.local:8500"
    SD_TLS: "false"
    SD_WORKLOAD: "client-prod"
```

**Before (v1.2.2):** The helper would **not** activate (missing `global.serviceDiscovery.address`). Operators had to set all `SD_*` variables manually in `extraEnvVars`.

**After (v1.3.0):** The helper **activates** from `configmap.SD_ADDRESS` and derives the full `SD_*` block:

```yaml
# Rendered ConfigMap (v1.3.0)
data:
  SD_ENABLED: "true"
  SD_ADDRESS: "consul.client.local:8500"
  SD_TLS: "false"
  SD_WORKLOAD: "client-prod"
  SD_PREFER_VIEW: "internal"
  SD_INTERNAL_ADDRESS: "myapp.default.svc.cluster.local"
  SD_INTERNAL_PORT: "8080"
  SD_INTERNAL_SCHEME: "http"
```

> **Note:** The `SD_ADDRESS` value comes from `configmap.SD_ADDRESS` (legacy), not `global.serviceDiscovery.address`. Component-level values always take precedence over global defaults.

### 2. Improved Precedence Logic

The precedence logic for all `SD_*` environment variables now uses **presence-based** resolution instead of truthiness-based.

#### What changed

**Before (v1.2.2):**

The helper used Sprig's `default` function to resolve precedence:

```yaml
SD_TLS: {{ index $c "SD_TLS" | default ($sd.tls | default false) | quote }}
```

**Problem:** Sprig's `default` treats empty string (`""`), `false`, and `0` as "empty" and falls through to the fallback. This meant:

- Setting `configmap.SD_TLS: false` to override `global.serviceDiscovery.tls: true` would **not work** (the global value would win)
- Setting `configmap.SD_WORKLOAD: ""` to override `global.serviceDiscovery.workload: "production"` would **not work** (the global value would win)

**After (v1.3.0):**

The helper uses **presence-based** resolution with `hasKey`:

```yaml
{{- $tls := ($sd.tls | default false) -}}
{{- if hasKey $c "SD_TLS" -}}
  {{- $tls = index $c "SD_TLS" -}}
{{- end -}}
SD_TLS: {{ $tls | quote }}
```

**Precedence per key:**

1. **Component-level `configmap.SD_*` key is present:** Use the component value (even if empty/false/0)
2. **Component-level key is absent:** Use the global default from `global.serviceDiscovery.*`
3. **Global default is absent:** Use the helper's built-in default

| Scenario | v1.2.2 | v1.3.0 |
|----------|---------|---------|
| `global.serviceDiscovery.tls: true`, `configmap.SD_TLS: false` | Renders `SD_TLS: "true"` ❌ | Renders `SD_TLS: "false"` ✅ |
| `global.serviceDiscovery.workload: "prod"`, `configmap.SD_WORKLOAD: ""` | Renders `SD_WORKLOAD: "prod"` ❌ | Renders `SD_WORKLOAD: ""` ✅ |
| `global.serviceDiscovery.tlsSkipVerify: true`, no `configmap.SD_TLS_SKIP_VERIFY` | Renders `SD_TLS_SKIP_VERIFY: "true"` ✅ | Renders `SD_TLS_SKIP_VERIFY: "true"` ✅ |

#### Why it matters

Operators can now **explicitly override** global Service Discovery settings with empty or false values at the component level. This is critical for:

- **Disabling TLS for a specific component** in an environment where `global.serviceDiscovery.tls: true`
- **Clearing the workload isolation key** for a component that should not participate in workload-based routing
- **Setting component-specific ports** (e.g. `SD_EXTERNAL_PORT: 8443`) that differ from the global default

#### Configuration example

**Environment-wide defaults with component-level overrides:**

```yaml
global:
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    tls: true
    tlsSkipVerify: false
    workload: "production"
    preferView: "external"

myapp:
  configmap:
    SD_ENABLED: "true"
    SD_TLS: false              # Override: disable TLS for this component
    SD_WORKLOAD: ""            # Override: clear workload isolation
    SD_PREFER_VIEW: "internal" # Override: prefer internal view
```

**Rendered ConfigMap (v1.3.0):**

```yaml
data:
  SD_ENABLED: "true"
  SD_ADDRESS: "consul.prod.example.com:443"        # from global
  SD_TLS: "false"                                  # from configmap (overrides global)
  SD_TLS_SKIP_VERIFY: "false"                      # from global
  SD_WORKLOAD: ""                                  # from configmap (overrides global)
  SD_PREFER_VIEW: "internal"                       # from configmap (overrides global)
  SD_INTERNAL_ADDRESS: "myapp.default.svc.cluster.local"
  SD_INTERNAL_PORT: "8080"
  SD_INTERNAL_SCHEME: "http"                       # from global
```

> **Important:** The component-level override applies **only when the key is present** in `configmap`. If `configmap.SD_TLS` is absent, the global `serviceDiscovery.tls` value is used.

## Configuration Reference

No new configuration fields were added in v1.3.0. The existing `global.serviceDiscovery` contract remains unchanged.

**Supported activation sources:**

| Source | Description | Precedence |
|--------|-------------|------------|
| `global.serviceDiscovery.address` | Environment-wide Service Discovery server address | Fallback (used when `configmap.SD_ADDRESS` is absent) |
| `configmap.SD_ADDRESS` | Legacy per-component Service Discovery server address | Highest (overrides global) |

**Precedence for all `SD_*` environment variables:**

1. Component-level `configmap.SD_*` key (if present, even if empty/false/0)
2. Environment-wide `global.serviceDiscovery.*` field
3. Helper built-in default

**Example umbrella `values.yaml` (unchanged from v1.2.2):**

```yaml
global:
  serviceDiscovery:
    address: "consul.prod.example.com:443"
    tls: true
    tlsSkipVerify: false
    workload: "production"
    preferView: "external"
    internalScheme: "http"
    externalPort: 443
```

**Example legacy deployment (on-prem, no global block):**

```yaml
myapp:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.client.local:8500"
    SD_TLS: "false"
    SD_WORKLOAD: "client-prod"
```

## Migration Steps

### For Operators Using `global.serviceDiscovery`

**No action required.** Existing deployments using the environment-wide `global.serviceDiscovery.address` continue to work unchanged.

If you need to override global settings for a specific component, you can now set explicit empty or false values in `configmap.SD_*`:

```yaml
myapp:
  configmap:
    SD_ENABLED: "true"
    SD_TLS: false              # Disable TLS for this component
    SD_WORKLOAD: ""            # Clear workload isolation
```

### For Operators Using Legacy `configmap.SD_*`

**No action required.** Deployments using legacy `configmap.SD_ENABLED=true` + `configmap.SD_ADDRESS` (no `global.serviceDiscovery` block) now correctly activate the helper and derive the full `SD_*` environment variable block.

**Before (v1.2.2):** You had to manually set all `SD_*` variables in `extraEnvVars` or `configmap`.

**After (v1.3.0):** The helper derives the full block from your existing `configmap.SD_ADDRESS` and other `configmap.SD_*` values.

#### Verification steps

1. **Upgrade to v1.3.0** (see [Command to upgrade](#command-to-upgrade))

2. **Verify the rendered ConfigMap** includes the full `SD_*` block:

```bash
helm get manifest <release-name> -n <namespace> | grep -A 20 "kind: ConfigMap"
```

Expected output:

```yaml
data:
  SD_ENABLED: "true"
  SD_ADDRESS: "consul.client.local:8500"
  SD_TLS: "false"
  SD_WORKLOAD: "client-prod"
  SD_PREFER_VIEW: "internal"
  SD_INTERNAL_ADDRESS: "myapp.default.svc.cluster.local"
  SD_INTERNAL_PORT: "8080"
  SD_INTERNAL_SCHEME: "http"
```

3. **Remove redundant `extraEnvVars`** (optional): If you were manually setting `SD_*` variables in `extraEnvVars` to work around the v1.2.2 limitation, you can now remove them:

**Before (v1.2.2 workaround):**

```yaml
myapp:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.client.local:8500"
  extraEnvVars:
    - name: SD_TLS
      value: "false"
    - name: SD_WORKLOAD
      value: "client-prod"
    - name: SD_PREFER_VIEW
      value: "internal"
    - name: SD_INTERNAL_ADDRESS
      value: "myapp.default.svc.cluster.local"
    - name: SD_INTERNAL_PORT
      value: "8080"
    - name: SD_INTERNAL_SCHEME
      value: "http"
```

**After (v1.3.0):**

```yaml
myapp:
  configmap:
    SD_ENABLED: "true"
    SD_ADDRESS: "consul.client.local:8500"
    SD_TLS: "false"
    SD_WORKLOAD: "client-prod"
```

> **Note:** The helper now derives `SD_PREFER_VIEW`, `SD_INTERNAL_ADDRESS`, `SD_INTERNAL_PORT`, and `SD_INTERNAL_SCHEME` automatically. You only need to set component-specific overrides in `configmap`.

### For Chart Maintainers

**No action required.** Product charts that consume `lerian-common.serviceDiscovery.env` automatically benefit from the improved activation and precedence logic.

If your product chart's tests or documentation assume the v1.2.2 behavior (helper only activates from `global.serviceDiscovery.address`), update them to reflect the new dual-activation support.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading to v1.3.0, run `helm diff` on the **product charts** that consume it.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.0 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `1.3.0` and run `helm dependency update`, then upgrade the umbrella/product chart.
