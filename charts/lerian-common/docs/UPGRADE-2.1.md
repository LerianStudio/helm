# Helm Upgrade from v2.0.0 to v2.1.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Datastore Mask Resolver: CA Certificate and Protocol Support](#1-datastore-mask-resolver-ca-certificate-and-protocol-support)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v2.1.0 extends the **datastore mask resolver** to support two new canonical fields: `caCert` and `protocol`. These fields enable operators to configure TLS certificate authorities and connection protocols (e.g. `mongodb+srv`, `postgres`, `redis`) via the unified datastore mask API.

**What changed:**

- The `lerian-common.datastore.value` helper now accepts `caCert` and `protocol` as valid `field` inputs
- Operators can now declare `global.datastores.<type>.caCert` and `global.datastores.<type>.protocol` for global defaults
- Component-level overrides via `configmap.*` keys continue to take precedence over mask values

**Who is affected:**

- Operators who need to configure custom CA certificates for datastore connections (e.g. self-signed certificates, private PKI)
- Operators who need to specify connection protocols explicitly (e.g. `mongodb+srv` for MongoDB Atlas, `rediss` for Redis with TLS)
- Chart maintainers who consume `lerian-common` and want to expose CA certificate and protocol configuration to operators

**Backward compatibility:**

This is a **backward-compatible enhancement**. Existing deployments that do not use `caCert` or `protocol` fields continue to work unchanged. The new fields are optional and only emitted when explicitly configured.

## Features

### 1. Datastore Mask Resolver: CA Certificate and Protocol Support

The `lerian-common.datastore.value` helper now supports two new canonical fields for datastore configuration.

#### What changed

The helper's `field` parameter now accepts `caCert` and `protocol` in addition to the existing fields (`host`, `replicaHost`, `user`, `port`, `ssl`, `params`).

**Supported fields (v2.1.0):**

| Field | Description | Example Value |
|-------|-------------|---------------|
| `host` | Primary datastore host | `postgres.prod.svc.cluster.local` |
| `replicaHost` | Read replica host | `postgres-replica.prod.svc.cluster.local` |
| `user` | Database username | `myapp-user` |
| `port` | Connection port | `5432` |
| `ssl` | Enable SSL/TLS | `true` |
| `params` | Connection parameters | `sslmode=require&connect_timeout=10` |
| `caCert` | **NEW** CA certificate (PEM format or path) | `/etc/ssl/certs/ca.pem` |
| `protocol` | **NEW** Connection protocol/scheme | `mongodb+srv`, `postgres`, `rediss` |

#### Why it matters

**CA Certificate (`caCert`):**

Many production environments use private certificate authorities or self-signed certificates for datastore connections. Before v2.1.0, operators had to configure CA certificates via native component keys (e.g. `DB_POSTGRES_CA_CERT`) without the benefit of the mask resolver's precedence chain.

v2.1.0 enables operators to:

- Set a global CA certificate for all components using a datastore type via `global.datastores.<type>.caCert`
- Override the CA certificate per component via `configmap.<NATIVE_KEY>`
- Use the same precedence chain as other datastore fields

**Protocol (`protocol`):**

Some datastores require explicit protocol specification in connection strings:

- **MongoDB Atlas:** Requires `mongodb+srv` protocol for SRV record resolution
- **Redis with TLS:** May use `rediss` protocol instead of `redis`
- **PostgreSQL with custom drivers:** May require `postgres` vs `postgresql` protocol

Before v2.1.0, operators had to construct full connection strings manually or use native component keys. v2.1.0 enables protocol configuration via the mask resolver.

#### Configuration examples

**Global CA certificate for PostgreSQL:**

```yaml
# Umbrella values.yaml
global:
  datastores:
    postgres:
      host: "postgres.prod.svc.cluster.local"
      port: "5432"
      ssl: "true"
      caCert: "/etc/ssl/certs/postgres-ca.pem"
```

**Component-level CA certificate override:**

```yaml
# Component values.yaml
myapp:
  configmap:
    DB_POSTGRES_CA_CERT: "/etc/ssl/certs/myapp-custom-ca.pem"  # Overrides global
```

**Global protocol for MongoDB:**

```yaml
# Umbrella values.yaml
global:
  datastores:
    mongo:
      protocol: "mongodb+srv"
      host: "cluster0.mongodb.net"
      user: "myapp-user"
```

**Component-level protocol override:**

```yaml
# Component values.yaml
myapp:
  configmap:
    MONGO_PROTOCOL: "mongodb"  # Override to use standard protocol instead of SRV
```

**Redis with TLS protocol:**

```yaml
# Umbrella values.yaml
global:
  datastores:
    redis:
      protocol: "rediss"
      host: "redis.prod.svc.cluster.local"
      port: "6380"
      ssl: "true"
      caCert: "/etc/ssl/certs/redis-ca.pem"
```

#### Usage in product chart templates

Product chart maintainers can now use the helper to resolve `caCert` and `protocol` fields:

```yaml
# ConfigMap template in product chart
data:
  DB_POSTGRES_CA_CERT: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" .Values.myapp.configmap "type" "postgres" "field" "caCert" "nativeKey" "DB_POSTGRES_CA_CERT") | quote }}
  DB_POSTGRES_PROTOCOL: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" .Values.myapp.configmap "type" "postgres" "field" "protocol" "nativeKey" "DB_POSTGRES_PROTOCOL") | quote }}
  MONGO_PROTOCOL: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" .Values.myapp.configmap "type" "mongo" "field" "protocol" "nativeKey" "MONGO_PROTOCOL") | quote }}
  REDIS_PROTOCOL: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" .Values.myapp.configmap "type" "redis" "field" "protocol" "nativeKey" "REDIS_PROTOCOL") | quote }}
```

#### Precedence

The precedence chain remains unchanged:

1. **Native configmap key** (e.g. `configmap.DB_POSTGRES_CA_CERT`) — highest precedence
2. **Dedicated datastores** (monolithic charts: `<component>.datastores.<type>.<field>`)
3. **Global datastores** (`global.datastores.<type>.<field>`)
4. **Default value** (optional `default` parameter in helper call) — lowest precedence

**Example precedence resolution for `caCert`:**

```yaml
# Umbrella values.yaml
global:
  datastores:
    postgres:
      caCert: "/etc/ssl/certs/global-ca.pem"

myapp:
  datastores:
    postgres:
      caCert: "/etc/ssl/certs/myapp-ca.pem"
  configmap:
    DB_POSTGRES_CA_CERT: "/etc/ssl/certs/override-ca.pem"
```

**Resolved value:** `/etc/ssl/certs/override-ca.pem` (native configmap key wins)

#### Operational impact

> **Note:** This is a **backward-compatible enhancement**. Existing deployments that do not configure `caCert` or `protocol` fields continue to work unchanged. The helper only emits these fields when explicitly configured.

**For operators:**

- If you need to configure CA certificates or protocols for datastore connections, you can now use the unified mask API instead of native component keys
- If you already use native component keys (e.g. `DB_POSTGRES_CA_CERT`), they continue to work and take precedence over mask values

**For chart maintainers:**

- Update your product chart templates to use the helper for `caCert` and `protocol` fields if your application supports them
- Document the new fields in your product chart's `values.yaml` and upgrade guide

## Configuration Reference

The following table shows the new fields supported by the `lerian-common.datastore.value` helper:

| Field | Type | Description | Example Value |
|-------|------|-------------|---------------|
| `caCert` | string | CA certificate for TLS verification (PEM format or file path) | `/etc/ssl/certs/ca.pem` |
| `protocol` | string | Connection protocol/scheme | `mongodb+srv`, `postgres`, `rediss` |

**Full datastore configuration block (umbrella `values.yaml`):**

```yaml
global:
  datastores:
    postgres:
      host: "postgres.prod.svc.cluster.local"
      replicaHost: "postgres-replica.prod.svc.cluster.local"
      user: "myapp-user"
      port: "5432"
      ssl: "true"
      params: "sslmode=require&connect_timeout=10"
      caCert: "/etc/ssl/certs/postgres-ca.pem"  # NEW in v2.1.0
      protocol: "postgres"                       # NEW in v2.1.0
    
    mongo:
      host: "cluster0.mongodb.net"
      user: "myapp-user"
      port: "27017"
      ssl: "true"
      caCert: "/etc/ssl/certs/mongo-ca.pem"     # NEW in v2.1.0
      protocol: "mongodb+srv"                    # NEW in v2.1.0
    
    redis:
      host: "redis.prod.svc.cluster.local"
      port: "6380"
      ssl: "true"
      caCert: "/etc/ssl/certs/redis-ca.pem"     # NEW in v2.1.0
      protocol: "rediss"                         # NEW in v2.1.0
```

**Component-level override (product chart `values.yaml`):**

```yaml
myapp:
  configmap:
    DB_POSTGRES_CA_CERT: "/etc/ssl/certs/myapp-custom-ca.pem"
    DB_POSTGRES_PROTOCOL: "postgresql"
    MONGO_PROTOCOL: "mongodb"
    REDIS_PROTOCOL: "redis"
```

> **Important:** The `caCert` and `protocol` fields are **optional**. Omit them if your datastore connections do not require custom CA certificates or explicit protocol specification.

## Migration Steps

### For Operators (Umbrella Deployments)

If you manage Lerian product charts via an umbrella chart and need to configure CA certificates or connection protocols:

1. **Review your current datastore configuration** in your umbrella `values.yaml`:

```bash
grep -A 10 "datastores:" values.yaml
```

2. **Determine if you need to configure CA certificates or protocols:**

   - **CA certificates:** Required if your datastores use self-signed certificates or private PKI
   - **Protocols:** Required if your datastores need explicit protocol specification (e.g. MongoDB Atlas with `mongodb+srv`)

3. **Add the new fields to your umbrella `values.yaml` if needed:**

```yaml
global:
  datastores:
    postgres:
      host: "postgres.prod.svc.cluster.local"
      port: "5432"
      ssl: "true"
      caCert: "/etc/ssl/certs/postgres-ca.pem"  # Add this line
      protocol: "postgres"                       # Add this line if needed
    
    mongo:
      host: "cluster0.mongodb.net"
      user: "myapp-user"
      caCert: "/etc/ssl/certs/mongo-ca.pem"     # Add this line
      protocol: "mongodb+srv"                    # Add this line for Atlas
```

4. **If you previously used native component keys**, you can migrate to the mask API or keep the native keys (they take precedence):

**Option 1: Keep existing native keys (no migration required):**

```yaml
myapp:
  configmap:
    DB_POSTGRES_CA_CERT: "/etc/ssl/certs/myapp-ca.pem"  # Continues to work
```

**Option 2: Migrate to global mask (cleaner for multi-component deployments):**

```yaml
# Remove component-level native keys
# myapp:
#   configmap:
#     DB_POSTGRES_CA_CERT: "/etc/ssl/certs/myapp-ca.pem"

# Add global mask instead
global:
  datastores:
    postgres:
      caCert: "/etc/ssl/certs/postgres-ca.pem"
```

5. **Preview the changes** (see [Preview changes before upgrading](#preview-changes-before-upgrading))

6. **Upgrade the umbrella chart:**

```bash
helm upgrade my-umbrella . -n lerian --values values.yaml
```

7. **Verify datastore connections** after upgrade:

   - Check application logs for successful datastore connections
   - Verify that TLS certificate validation works correctly (if using `caCert`)
   - Monitor for connection errors related to protocol mismatches

### For Standalone Deployments

If you deploy a single product chart without an umbrella:

1. **Check if the product chart has adopted `lerian-common` v2.1.0** (review the product chart's `Chart.yaml` dependencies)

2. **If the product chart supports `caCert` or `protocol` fields**, review your component-level configuration:

```yaml
myapp:
  configmap:
    DB_POSTGRES_CA_CERT: "/etc/ssl/certs/myapp-ca.pem"
    DB_POSTGRES_PROTOCOL: "postgres"
```

> **Note:** Component-level `configmap.*` values always take precedence over `global.datastores.*` mask values. If you have set these values at the component level, no change in behavior will occur.

### For Chart Maintainers (Product Charts)

If you maintain a Lerian product chart that consumes `lerian-common`:

1. **Update the `lerian-common` dependency** in your product chart's `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common-helm
    version: 2.1.0
    repository: oci://registry-1.docker.io/lerianstudio
```

2. **Update dependencies:**

```bash
helm dependency update
```

3. **Update your ConfigMap templates** to use the helper for `caCert` and `protocol` fields (if your application supports them):

```yaml
# templates/configmap.yaml
data:
  DB_POSTGRES_CA_CERT: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" .Values.myapp.configmap "type" "postgres" "field" "caCert" "nativeKey" "DB_POSTGRES_CA_CERT") | quote }}
  DB_POSTGRES_PROTOCOL: {{ include "lerian-common.datastore.value" (dict "context" $ "configmap" .Values.myapp.configmap "type" "postgres" "field" "protocol" "nativeKey" "DB_POSTGRES_PROTOCOL") | quote }}
```

4. **Document the new fields** in your product chart's `values.yaml`:

```yaml
myapp:
  configmap:
    # PostgreSQL CA certificate (PEM format or file path)
    # Falls back to global.datastores.postgres.caCert if not set
    DB_POSTGRES_CA_CERT: ""
    
    # PostgreSQL connection protocol
    # Falls back to global.datastores.postgres.protocol if not set
    DB_POSTGRES_PROTOCOL: ""
```

5. **Test the new fields** with your product chart:

```bash
helm template my-chart . --values test-values.yaml | grep -A 2 "DB_POSTGRES_CA_CERT\|DB_POSTGRES_PROTOCOL"
```

6. **Document the change** in your product chart's release notes

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.1.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading to v2.1.0, run `helm diff` on the **product charts** or **umbrella chart** that consume it after updating their dependency to v2.1.0.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.1.0 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `2.1.0` and run `helm dependency update`, then upgrade the consuming chart.
