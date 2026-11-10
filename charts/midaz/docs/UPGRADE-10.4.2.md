# Helm Upgrade from v10.4.1 to v10.4.2

## Topics

- **[Configuration Changes](#configuration-changes)**
  - [1. Per-component Kafka SASL opt-out documentation](#1-per-component-kafka-sasl-opt-out-documentation)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Configuration Changes

### 1. Per-component Kafka SASL opt-out documentation

**Who is affected:** Operators who need to configure different Kafka authentication settings per component, or who need to disable SASL authentication for specific services while keeping it enabled globally.

#### What changed

The chart now documents how to override global Kafka SASL settings on a per-component basis. This is a documentation-only change — no template logic or default values have been modified.

| Setting | v10.4.1 | v10.4.2 |
|---------|---------|---------|
| `global.streaming` documentation | Basic SASL configuration example | Includes per-component opt-out instructions |

**Before (v10.4.1):**

The `global.streaming` section showed only the shared SASL configuration:

```yaml
global:
  streaming:
    saslMechanism: "PLAIN"
    saslUsername: "midaz"
    tlsEnabled: "true"
```

**After (v10.4.2):**

The documentation now includes guidance for per-component overrides:

```yaml
global:
  streaming:
    saslMechanism: "PLAIN"
    saslUsername: "midaz"
    tlsEnabled: "true"
  # Per-component opt-out: set ledger.configmap.STREAMING_SASL_MECHANISM: "" and
  # STREAMING_SASL_USERNAME: "" (and leave its STREAMING_SASL_PASSWORD empty) to drop the shared SASL.
```

#### Why it matters

Previously, operators who needed to disable SASL authentication for a specific component (e.g., the ledger) while keeping it enabled globally had no documented pattern to follow. The chart has always supported per-component overrides through the component-level `configmap` blocks, but this capability was not documented in the `global.streaming` section.

This change makes it clear that:

- Global `streaming` settings apply to all components by default
- Individual components can opt out by explicitly setting their `STREAMING_SASL_MECHANISM` and `STREAMING_SASL_USERNAME` to empty strings
- The `STREAMING_SASL_PASSWORD` must also be left empty (or unset) for the opt-out to take effect

#### Action required

**None.** This is a documentation enhancement only. Existing deployments continue to work unchanged.

#### Optional: Using per-component opt-out

If you need to disable SASL authentication for a specific component while keeping global SASL enabled, use the following pattern:

```yaml
global:
  streaming:
    saslMechanism: "PLAIN"
    saslUsername: "midaz"
    tlsEnabled: "true"

ledger:
  configmap:
    STREAMING_SASL_MECHANISM: ""
    STREAMING_SASL_USERNAME: ""
  # Do not set STREAMING_SASL_PASSWORD or set it to ""
```

This configuration:

- Enables SASL authentication globally for all components
- Disables SASL authentication only for the ledger
- Other components (tracer, CRM, etc.) continue using the global SASL settings

> **Note:** The component-level `configmap` values always take precedence over `global.streaming` values. Setting a value to an empty string explicitly overrides the global default.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.4.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.4.2
```
