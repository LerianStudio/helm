# Helm Upgrade from v1.4.4 to v1.5.0

## Topics

- **[Features](#features)**
  - [New STA document type support (AJUD302B)](#new-sta-document-type-support-ajud302b)
- **[Configuration Reference](#configuration-reference)**
  - [New environment variables](#new-environment-variables)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Features

### New STA document type support (AJUD302B)

The chart now supports a new document type for STA (Sistema de Transferência de Arquivos) integration: `AJUD302B`. This extends the existing AJUD302 and AJUD309 document type configuration.

**What changed:**

| Setting | v1.4.4 | v1.5.0 |
|---------|--------|--------|
| STA document types | AJUD302, AJUD309 | AJUD302, AJUD309, AJUD302B |
| Environment variable | Not available | `STA_DOCUMENT_TYPE_AJUD302B` |
| Default value | N/A | `"AJUD302B"` |

**Template changes:**

The `_helpers.tpl` template now includes an additional environment variable for the new document type.

**Before (v1.4.4):**

```yaml
STA_DOCUMENT_TYPE_AJUD302: "AJUD302"
STA_DOCUMENT_TYPE_AJUD309: "AJUD309"
STA_CLIENT_ID: ""
```

**After (v1.5.0):**

```yaml
STA_DOCUMENT_TYPE_AJUD302: "AJUD302"
STA_DOCUMENT_TYPE_AJUD309: "AJUD309"
STA_DOCUMENT_TYPE_AJUD302B: "AJUD302B"
STA_CLIENT_ID: ""
```

**Why this matters:**

The AJUD302B document type is a new variant of the AJUD302 format used in the Brazilian judicial system's file transfer integration. Applications that need to process this document type can now configure it through the chart.

**Configuration:**

The new document type is configured via the `brSisbajud.sta.documentTypeAjud302b` field in your values file:

```yaml
brSisbajud:
  sta:
    documentTypeAjud302: "AJUD302"
    documentTypeAjud309: "AJUD309"
    documentTypeAjud302b: "AJUD302B"  # New field
    clientId: "your-client-id"
```

**Default behavior:**

If you do not explicitly set `brSisbajud.sta.documentTypeAjud302b`, the chart will use the default value `"AJUD302B"`. This ensures backward compatibility—existing deployments will automatically receive the new environment variable with its default value.

> **Note:** No action is required for this upgrade. The new document type configuration is additive and does not affect existing AJUD302 or AJUD309 processing.

**Customizing the document type:**

If your STA integration requires a different identifier for the AJUD302B document type, override it in your values file:

```yaml
brSisbajud:
  sta:
    documentTypeAjud302b: "CUSTOM_AJUD302B_TYPE"
```

---

## Configuration Reference

### New environment variables

The following environment variable has been added to the application ConfigMap:

| Variable | Default | Source | Description |
|----------|---------|--------|-------------|
| `STA_DOCUMENT_TYPE_AJUD302B` | `"AJUD302B"` | `brSisbajud.sta.documentTypeAjud302b` | Document type identifier for AJUD302B format in STA integration |

**Full STA configuration context:**

```yaml
brSisbajud:
  sta:
    # File lock configuration
    fileLockTtl: "300"
    
    # Consumer settings
    consumerEnabled: "true"
    consumerRetryBudget: "3"
    
    # Product and system identification
    sourceProduct: "br-sisbajud"
    bacenSystemCode: "SISBAJUD"
    expectedTenantSt: "single-tenant"
    
    # Transfer settings
    transfersEnabled: "true"
    transfersBaseUrl: "https://sta.example.com"
    maxInboundSizeBytes: "104857600"
    
    # Document type identifiers
    documentTypeAjud302: "AJUD302"
    documentTypeAjud309: "AJUD309"
    documentTypeAjud302b: "AJUD302B"  # New in v1.5.0
    
    # Authentication
    clientId: "your-client-id"
    
    # Kafka stream configuration (br-sta's own cluster)
    stream:
      bootstrapServers: "kafka.example.com:9092"
      groupId: "br-sisbajud-consumer"
```

> **Important:** The `STA_CLIENT_SECRET` is configured separately via `brSisbajud.secrets` and is not part of the ConfigMap.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm -n br-sisbajud --version 1.5.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm -n br-sisbajud --version 1.5.0
```
