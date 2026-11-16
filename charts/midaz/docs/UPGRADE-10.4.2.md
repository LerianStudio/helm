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

The chart documents per-component Kafka SASL overrides and fixes `values.schema.json` to accept `STREAMING_SASL_MECHANISM` and `STREAMING_SASL_USERNAME` in the ledger and tracer `configmap` blocks. Version 10.4.1 rejects those keys during schema validation; 10.4.2 accepts them. This is not a documentation-only change. Template logic and runtime defaults remain unchanged, as does application version 4.4.1. A chart test also now accepts patch-level 4.4.x ledger image tags.

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

Previously, the template-level override behavior was not fully documented, and the 10.4.1 schema rejected the ledger and tracer keys needed by this pattern. Version 10.4.2 makes these overrides usable through schema validation as well as documenting them.

This change makes it clear that:

- Global `streaming` settings apply to all components by default
- Individual components can opt out by explicitly setting their `STREAMING_SASL_MECHANISM` and `STREAMING_SASL_USERNAME` to empty strings
- The `STREAMING_SASL_PASSWORD` must also be left empty (or unset) for the opt-out to take effect

#### Action required

Existing deployments that do not need these overrides require no configuration change. Operators using the opt-out must upgrade to the schema that accepts it and include the desired overrides in their complete intended configuration.

#### Optional: Using per-component opt-out

If you need to disable SASL authentication for a specific component while retaining shared SASL settings, merge the following fragment into your existing configuration. It does not enable streaming: preserve your actual brokers and each intended component's `STREAMING_ENABLED` setting, credentials, Secret references and other prerequisites. Defaults leave streaming disabled. Do not use this fragment as a complete values file.

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

- Selects shared SASL settings for components that already have streaming enabled
- Overrides the ledger mechanism and username with empty strings; ensure its effective password is empty too
- Leaves other enabled components inheriting the shared settings unless they override them; their own valid credentials are still required

> **Note:** The component-level `configmap` values take precedence over the corresponding shared SASL values. The ledger broker listener must permit connections without SASL. Inspect existing password settings and Secret references privately; do not overwrite unrelated credentials to clear one field.

Before previewing, save current release values and manifests privately, retain the prior chart version and normal data backups, and prepare `midaz-values.yaml` as the **complete intended configuration**. Preserve unrelated settings, image pins, storage and Secret references. Do not commit live credentials. The commands below use `--reset-values -f`: omitted settings fall back to chart defaults rather than retaining old stored overrides. Render and inspect the effective streaming configuration privately before applying. This chart patch does not change the application version; static validation is not an exercised upgrade or restore. Helm rollback does not restore application data.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.4.2 --reset-values -f midaz-values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 10.4.2 --reset-values -f midaz-values.yaml
```
