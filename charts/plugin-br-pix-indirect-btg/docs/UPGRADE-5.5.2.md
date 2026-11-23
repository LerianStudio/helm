# Helm Upgrade from v5.5.1 to v5.5.2

## Topics

- **[Overview](#overview)**
- **[Enhancements](#enhancements)**
  - [API documentation links in NOTES.txt](#api-documentation-links-in-notestxt)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that enhances the post-install/upgrade output (NOTES.txt) by adding comprehensive API documentation links. The application version remains `1.15.0` and no values are changed, so existing custom values continue to work without modification.

The expected upgrade path is an in-place Helm upgrade with no configuration changes required.

## Enhancements

### API documentation links in NOTES.txt

The Helm chart now prints a complete set of API documentation URLs after every install or upgrade, helping operators quickly locate the error catalog, webhook event documentation, and per-module endpoint references.

**What changed:**

The `NOTES.txt` template now includes a new section titled **📖 API Documentation (application 1.10.0 and later)** that dynamically constructs documentation URLs based on your ingress configuration and the `SWAGGER_ENABLED` flag.

**Why it matters:**

Operators no longer need to manually construct documentation URLs or search through application logs to find the Swagger UI or webhook event reference. The chart automatically detects whether ingress is enabled and whether Swagger endpoints are exposed, then prints the correct URLs.

**Documentation URLs provided:**

| Documentation type | Path | Availability |
|-------------------|------|--------------|
| Error catalog and integration guide | `/swagger/index.html` | Always available |
| Webhook events | `/docs/webhooks` | Always available |
| Per-module endpoint reference | `/v1/<module>/docs` | Only when `pix.configmap.SWAGGER_ENABLED` is `"true"` |

The per-module endpoint reference covers these modules:

- `dict`
- `payment`
- `collections`
- `brcode`
- `qrcodes`
- `recurrences`
- `webhooks`

Each module also serves `/openapi.json` and `/openapi.yaml` when Swagger is enabled.

**Base URL detection:**

The chart constructs the base documentation URL using the following logic:

1. If `pix.ingress.enabled` is `true` and a host is configured, use the first ingress host with the appropriate scheme (`https://` if TLS is configured, `http://` otherwise).
2. Otherwise, fall back to `http://localhost:4014`.

**Example output (ingress enabled, Swagger enabled):**

```
📖 API Documentation (application 1.10.0 and later):

  - Error catalog and integration guide (no endpoints): https://pix.example.com/swagger/index.html
  - Webhook events: https://pix.example.com/docs/webhooks
  - Endpoint reference, one page per module:
      https://pix.example.com/v1/dict/docs
      https://pix.example.com/v1/payment/docs
      https://pix.example.com/v1/collections/docs
      https://pix.example.com/v1/brcode/docs
      https://pix.example.com/v1/qrcodes/docs
      https://pix.example.com/v1/recurrences/docs
      https://pix.example.com/v1/webhooks/docs
    Each module also serves /openapi.json and /openapi.yaml.
```

**Example output (Swagger disabled):**

```
📖 API Documentation (application 1.10.0 and later):

  - Error catalog and integration guide (no endpoints): http://localhost:4014/swagger/index.html
  - Webhook events: http://localhost:4014/docs/webhooks
  - Endpoint reference: off (pix.configmap.SWAGGER_ENABLED is "false").
    Set it to "true" to serve /v1/<module>/docs.
```

**Operational impact:**

This change affects only the post-install/upgrade output. No runtime behavior, configuration, or resource definitions are modified. Operators will see the new documentation section immediately after upgrading.

**Enabling Swagger endpoints:**

If you want to expose the per-module endpoint reference, ensure `SWAGGER_ENABLED` is set to `"true"` in your values:

```yaml
pix:
  configmap:
    SWAGGER_ENABLED: "true"
```

> **Note:** The `SWAGGER_ENABLED` flag controls whether the application serves `/v1/<module>/docs` endpoints. The error catalog (`/swagger/index.html`) and webhook documentation (`/docs/webhooks`) are always available regardless of this setting.

> **Important:** If your application version is older than `1.10.0`, some documentation endpoints may not be available. The NOTES.txt section is labeled "application 1.10.0 and later" to reflect this requirement. The current chart ships with `appVersion: 1.15.0`, so all endpoints are supported.

**No action required** to benefit from this enhancement. After upgrading, review the NOTES.txt output to confirm the documentation URLs match your ingress configuration.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.5.2
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm -n midaz-plugins --version 5.5.2
```
