# ⚠️ DEPRECATED — go-boilerplate-ddd-helm

This chart has been **moved to [helm-internal](https://github.com/LerianStudio/helm-internal)**.

## New location

```
oci://ghcr.io/lerianstudio/helm-internal/go-boilerplate-ddd-helm
```

## Migration

Update your `helmfile.yaml`:

```yaml
chart: oci://ghcr.io/lerianstudio/helm-internal/go-boilerplate-ddd-helm
version: "1.0.0"
```

## Breaking changes (v1.2.2+)

If upgrading the application to v1.2.2+, the following values are required:

```yaml
configmap:
  # OTEL endpoint is now injected with http:// prefix by the chart template
  # No changes needed for OTEL.
  
  # Required when POSTGRES_SSLMODE=disable or Redis is plain (no TLS):
  ALLOW_INSECURE_TLS: "true"
```

See the [helm-internal chart](https://github.com/LerianStudio/helm-internal/tree/main/charts/go-boilerplate-ddd) for the latest version.
