# Helm Upgrade from v4.1.0 to v4.2.0

## Topics

- **[Features](#features)**
  - [1. Midaz v2 API support for fees](#1-midaz-v2-api-support-for-fees)
- **[Configuration Reference](#configuration-reference)**
- **[Migration Steps](#migration-steps)**
  - [Scenario 1: Fees functionality not required](#scenario-1-fees-functionality-not-required)
  - [Scenario 2: Fees functionality required](#scenario-2-fees-functionality-required)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Midaz v2 API support for fees

Starting from version 4.2.0, the product-console chart supports the new Midaz ledger v2 API contract (`/v2`) for fees functionality. Fees — including fee packages, billing packages, billing runs, and the fees statement — have been moved from a separate plugin into the Midaz ledger itself under the `/v2` endpoint.

**What changed:**

| Setting | v4.1.0 | v4.2.0 |
|---------|--------|--------|
| `configmap.MIDAZ_V2_BASE_PATH` | Not present | Optional (no default) |
| Template helper `_helpers.tpl` | No v2 path handling | Includes `MIDAZ_V2_BASE_PATH` in optional env vars |
| ConfigMap template | No v2 configuration | Conditionally renders `MIDAZ_V2_BASE_PATH` |

**Why this matters:**

- The console now requires a separate endpoint to access fees functionality
- The existing v1 API (`MIDAZ_BASE_PATH`) continues to serve all non-fees operations
- Without `MIDAZ_V2_BASE_PATH` configured, all fees pages will fail and the console's health check will report `"MIDAZ_V2_BASE_PATH is not set"`
- The v1 and v2 endpoints coexist and point to the same Midaz ledger service, just different API versions

**New environment variable:**

| Variable | Default | Description |
|----------|---------|-------------|
| `MIDAZ_V2_BASE_PATH` | Not set | The address of the Midaz ledger's v2 API contract. Required for fees functionality. Must end with a trailing slash (e.g., `http://midaz-ledger.midaz.svc.cluster.local:3002/v2/`). |

> **Important:** The `MIDAZ_V2_BASE_PATH` value **must** end with a trailing slash (`/`). Without it, the console's relative path resolution will drop the `/v2` segment and calls will land on the wrong API contract with no error message. The console automatically adds the missing slash if omitted, but the canonical form includes it.

**Configuration example:**

```yaml
configmap:
  MIDAZ_V2_BASE_PATH: "http://midaz-ledger.midaz.svc.cluster.local:3002/v2/"
```

> **Note:** The v2 endpoint typically points to the same host and port as `MIDAZ_BASE_PATH` (or `MIDAZ_TRANSACTION_BASE_PATH`), with only the API version path changed from `/v1` to `/v2`.

## Configuration Reference

### New ConfigMap field

```yaml
configmap:
  # Optional: Address of the Midaz ledger v2 API for fees functionality
  # Format: http://<host>:<port>/v2/
  # Must include the trailing slash
  # If not set, fees pages will fail and health check will report the missing configuration
  MIDAZ_V2_BASE_PATH: ""
```

### Relationship to existing Midaz configuration

The v2 path complements the existing v1 configuration:

```yaml
configmap:
  # Existing v1 configuration (unchanged)
  MIDAZ_BASE_PATH: "http://midaz-ledger.midaz.svc.cluster.local:3002/v1"
  MIDAZ_TRANSACTION_BASE_HOST: "midaz-ledger.midaz.svc.cluster.local"
  MIDAZ_TRANSACTION_BASE_PORT: "3002"
  MIDAZ_TRANSACTION_BASE_PATH: "http://midaz-ledger.midaz.svc.cluster.local:3002/v1"
  
  # New v2 configuration for fees
  MIDAZ_V2_BASE_PATH: "http://midaz-ledger.midaz.svc.cluster.local:3002/v2/"
```

## Migration Steps

This upgrade requires no mandatory configuration changes. The chart will deploy successfully without setting `MIDAZ_V2_BASE_PATH`, but fees functionality will not work.

### Scenario 1: Fees functionality not required

If your deployment does not use fees functionality (fee packages, billing packages, billing runs, or fees statements), no action is required.

**Upgrade command:**

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.2.0 \
  -n product-console
```

> **Note:** The console health check will report `"MIDAZ_V2_BASE_PATH is not set"` but this does not affect other functionality.

### Scenario 2: Fees functionality required

If your deployment uses or will use fees functionality, you must configure `MIDAZ_V2_BASE_PATH` to point to your Midaz ledger's v2 API.

**Step 1:** Verify your Midaz ledger version supports the `/v2` API contract (Midaz v4.0.0 or later).

**Step 2:** Determine the v2 endpoint address. This is typically the same host and port as your existing `MIDAZ_BASE_PATH`, with `/v1` replaced by `/v2/`:

```yaml
# Example: if your current v1 path is
configmap:
  MIDAZ_BASE_PATH: "http://midaz-ledger.midaz.svc.cluster.local:3002/v1"

# Then your v2 path should be
configmap:
  MIDAZ_V2_BASE_PATH: "http://midaz-ledger.midaz.svc.cluster.local:3002/v2/"
```

**Step 3:** Add the configuration to your `values.yaml`:

```yaml
configmap:
  MIDAZ_V2_BASE_PATH: "http://midaz-ledger.midaz.svc.cluster.local:3002/v2/"
```

**Step 4:** Upgrade the chart:

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm \
  --version 4.2.0 \
  --set configmap.MIDAZ_V2_BASE_PATH="http://midaz-ledger.midaz.svc.cluster.local:3002/v2/" \
  -n product-console
```

**Step 5:** Verify the configuration after upgrade:

```bash
kubectl get configmap product-console -n product-console -o jsonpath='{.data.MIDAZ_V2_BASE_PATH}'
```

**Step 6:** Check that fees pages are accessible and the health check no longer reports the missing configuration:

```bash
kubectl logs -n product-console -l app.kubernetes.io/name=product-console --tail=50 | grep -i "MIDAZ_V2"
```

> **Warning:** If you set `MIDAZ_V2_BASE_PATH` to an incorrect address (wrong host, port, or path), fees pages will fail with connection errors or 404 responses. Ensure the address points to a Midaz ledger instance that supports the v2 API contract.

## Preview changes before upgrading

```bash
helm diff upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.0 -n product-console
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade product-console oci://registry-1.docker.io/lerianstudio/product-console-helm --version 4.2.0 -n product-console
```
