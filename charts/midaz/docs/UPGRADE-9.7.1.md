<!-- {% raw %} -->
# Helm Upgrade from v9.7.0 to v9.7.1

## Topics

- **[Application Version Update](#application-version-update)**
  - [1. Midaz application bump to 4.2.2](#1-midaz-application-bump-to-422)
  - [2. Image tag updates](#2-image-tag-updates)
- **[Documentation Updates](#documentation-updates)**
  - [1. Ledger datastores SSL configuration clarification](#1-ledger-datastores-ssl-configuration-clarification)
  - [2. Tracer transport mode documentation expanded](#2-tracer-transport-mode-documentation-expanded)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Application Version Update

### 1. Midaz application bump to 4.2.2

This patch release updates the Midaz application from version `4.2.1` to `4.2.2`. This is a minor patch update that includes bug fixes and stability improvements.

| Component | v9.7.0 | v9.7.1 |
|-----------|--------|--------|
| appVersion | 4.2.1 | 4.2.2 |

For detailed application-level changes, refer to the [Midaz application changelog](https://github.com/LerianStudio/midaz/blob/main/CHANGELOG.md).

### 2. Image tag updates

The following container image tags have been updated to align with the new application version:

| Component | v9.7.0 | v9.7.1 |
|-----------|--------|--------|
| ledger.image.tag | 4.2.1 | 4.2.2 |
| tracer.image.tag | 4.2.1 | 4.2.2 |

**Before (v9.7.0):**

```yaml
ledger:
  image:
    tag: "4.2.1"

tracer:
  image:
    tag: "4.2.1"
```

**After (v9.7.1):**

```yaml
ledger:
  image:
    tag: "4.2.2"

tracer:
  image:
    tag: "4.2.2"
```

> **Note:** If you have overridden these image tags in your `values.yaml`, ensure they are updated to `4.2.2` or removed to use the chart defaults.

#### Operational Impact

This is a straightforward patch upgrade with no breaking changes, configuration modifications, or migration steps required. The upgrade will:

- Pull new container images for the `ledger` and `tracer` components
- Perform a rolling update of the affected deployments
- Maintain backward compatibility with existing configurations

No operator action is required beyond running the upgrade command. Existing data, secrets, and configurations remain unchanged.

## Documentation Updates

### 1. Ledger datastores SSL configuration clarification

The `values.yaml` documentation for `ledger.datastores` has been updated to clarify how PostgreSQL SSL settings are read. This is a documentation-only change with no impact on rendered manifests or runtime behavior.

**Before (v9.7.0):**

```yaml
ledger:
  # -- Dedicated datastore masks for this component (override global.datastores).
  # Sub-keys: postgresOnboarding / postgresTransaction / mongoOnboarding /
  # mongoTransaction / mongoCrm / mongoFees / redis / broker (host/port/user/ssl/replicaHost).
  datastores: {}
```

**After (v9.7.1):**

```yaml
ledger:
  # -- Dedicated datastore masks for this component (override global.datastores).
  # Sub-keys: postgresOnboarding / postgresTransaction / mongoOnboarding /
  # mongoTransaction / mongoCrm / mongoFees / redis / broker (host/port/user/replicaHost).
  # The Postgres `ssl` field is read from the generic `postgres` key (`postgres.ssl`),
  # not from `postgresOnboarding`/`postgresTransaction`: those keys' `ssl` is ignored.
  datastores: {}
```

#### What this means

The ledger's ConfigMap template has always read the PostgreSQL SSL mode from `global.datastores.postgres.ssl` (or `ledger.datastores.postgres.ssl`), not from the database-specific keys `postgresOnboarding.ssl` or `postgresTransaction.ssl`. Setting SSL under those keys has no effect.

#### Operational impact

- **No configuration change required:** if you are already setting `postgres.ssl` under `global.datastores` or `ledger.datastores`, your configuration is correct and will continue to work.
- **If you set `postgresOnboarding.ssl` or `postgresTransaction.ssl`:** those values are ignored. Move the `ssl` setting to the `postgres` key instead.

**Correct configuration example:**

```yaml
ledger:
  datastores:
    postgres:
      ssl: "require"
    postgresOnboarding:
      host: "onboarding-db.example.com"
      port: "5432"
    postgresTransaction:
      host: "transaction-db.example.com"
      port: "5432"
```

### 2. Tracer transport mode documentation expanded

The ConfigMap template comment for `TRACER_TRANSPORT` has been expanded to clarify compatibility between ledger application versions and the transport mode setting.

**Before (v9.7.0):**

```yaml
{{- /* The seam accepts "grpc" or "rest". The bundled tracer only serves gRPC
       when TRACER_GRPC_PORT is set, so selecting grpc against an in-chart
       tracer that has it unset would dial a port nothing listens on. */ -}}
```

**After (v9.7.1):**

```yaml
{{- /* Ledger app up to 4.1.x accepts "grpc" or "rest"; from 4.2.0 only "grpc"
       (rest is refused at boot). The chart default stays "rest" so installs on
       older images render the same ConfigMap. This only matters when the tracer
       integration is configured: with TRACER_BASE_URL empty the ledger disables
       it and ignores TRACER_TRANSPORT. Set "grpc" once TRACER_BASE_URL is set on
       a 4.2+ ledger (see README, Ledger to tracer transport). The bundled
       tracer only serves gRPC through its Service when TRACER_GRPC_PORT is set, so
       selecting grpc against an in-chart tracer that has it unset would dial a
       port nothing listens on. */ -}}
```

#### What this means

- **Ledger 4.1.x and earlier:** accepts both `TRACER_TRANSPORT: "rest"` and `TRACER_TRANSPORT: "grpc"`
- **Ledger 4.2.0 and later:** only accepts `TRACER_TRANSPORT: "grpc"` and will refuse to boot if set to `"rest"` when the tracer integration is enabled
- **Chart default:** remains `"rest"` for backward compatibility with older ledger images
- **When it matters:** only when `TRACER_BASE_URL` is set (tracer integration enabled). With `TRACER_BASE_URL` empty, the ledger disables the tracer integration and ignores `TRACER_TRANSPORT`.

#### Operational impact

If you are upgrading to ledger 4.2.2 (included in this chart version) and have the tracer integration enabled, you must set `TRACER_TRANSPORT: "grpc"`:

```yaml
ledger:
  configmap:
    TRACER_BASE_URL: "http://midaz-tracer:8080"
    TRACER_TRANSPORT: "grpc"

tracer:
  enabled: true
  configmap:
    TRACER_GRPC_PORT: "50051"
```

> **Important:** If you enable `TRACER_TRANSPORT: "grpc"` with the bundled tracer, you must also set `tracer.configmap.TRACER_GRPC_PORT` (e.g., `"50051"`). Without it, the tracer Service will not expose the gRPC port, and the ledger will fail to connect.

If you are not using the tracer integration (`TRACER_BASE_URL` is empty or unset), no action is required.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.7.1 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.7.1 -n midaz
```
<!-- {% endraw %} -->
