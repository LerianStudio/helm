# ⚠️ DEPRECATED — plugin-br-payments-fakebtg-helm

This chart has been **moved to [helm-internal](https://github.com/LerianStudio/helm-internal)**.

fakebtg is an internal test double (BTG provider API stand-in) used only by
`plugin-br-payments` dev/staging environments, so it now lives alongside the
other internal charts (e.g. `mock-btg-server`, `go-boilerplate-ddd`).

## New location

```
oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm
```

## Migration

Update your `helmfile.yaml`:

```yaml
chart: oci://ghcr.io/lerianstudio/helm-internal/plugin-br-payments-fakebtg-helm
version: "1.0.0"
```

No values changes are required — the chart contents (templates, values,
schema) are unchanged; only the registry location moved.

See the [helm-internal chart](https://github.com/LerianStudio/helm-internal/tree/main/charts/plugin-br-payments-fakebtg) for the latest version.
