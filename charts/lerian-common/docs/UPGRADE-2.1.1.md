# Helm Upgrade from v2.1.0 to v2.1.1

## Topics ToC

- **[Fixes](#fixes)**
  - [1. OTEL_EXPORTER_OTLP_ENDPOINT URL Format](#1-otel_exporter_otlp_endpoint-url-format)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. OTEL_EXPORTER_OTLP_ENDPOINT URL Format

The `lerian-common.otel.podEnv` helper now emits `OTEL_EXPORTER_OTLP_ENDPOINT` as a **full URL** (`http://$(HOST_IP):4317`) instead of a bare `host:port` string.

#### What changed

The `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable format has been corrected to include a URL scheme.

| Setting | v2.1.0 | v2.1.1 |
|---------|---------|---------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` format | `$(HOST_IP):4317` | `http://$(HOST_IP):4317` |

**Before (v2.1.0):**

```yaml
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "$(HOST_IP):4317"
```

**After (v2.1.1):**

```yaml
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "http://$(HOST_IP):4317"
```

#### Why it matters

The OpenTelemetry SDK parses the `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable using `url.Parse` and **rejects bare `host:port` strings**. Without a URL scheme, the SDK fails to initialize the exporter, causing telemetry data to be silently dropped.

This fix ensures that applications using the `lerian-common.otel.podEnv` helper can successfully connect to the node-local OpenTelemetry collector.

#### Operational impact

> **Important:** This is a library chart (type: library) that is consumed as a dependency by other charts. It does not deploy resources directly.

**For operators:**

- If you are using product charts that have adopted `lerian-common.otel.podEnv`, upgrading to v2.1.1 will automatically fix the `OTEL_EXPORTER_OTLP_ENDPOINT` format in the next deployment.
- **No configuration changes are required** — the fix is applied automatically when product charts render the helper.
- Applications that were silently failing to export telemetry will begin successfully connecting to the collector after the upgrade.

**For chart maintainers:**

- If your product chart uses `lerian-common.otel.podEnv`, update the `lerian-common` dependency to v2.1.1 in your `Chart.yaml`:

```yaml
dependencies:
  - name: lerian-common
    version: 2.1.1
    repository: oci://registry-1.docker.io/lerianstudio
```

- Run `helm dependency update` to pull the new version.
- The rendered output will automatically include the corrected URL format.

#### New configuration option

The helper now accepts an optional `scheme` parameter to customize the URL scheme (default: `http`).

| Parameter | Default | Description |
|-----------|---------|-------------|
| `scheme` | `http` | URL scheme for the OTLP endpoint (`http` or `https`); trailing `://` is accepted and stripped |

**Usage example (product chart `deployment.yaml`):**

```yaml
env:
  {{- include "lerian-common.otel.podEnv" (dict "port" 4317 "scheme" "https" "podAttributes" true) | nindent 10 }}
```

**Rendered output:**

```yaml
- name: "OTEL_EXPORTER_OTLP_ENDPOINT"
  value: "https://$(HOST_IP):4317"
```

> **Note:** gRPC-based OpenTelemetry collectors accept `http://` for plaintext connections (gRPC does not use HTTP semantics for the scheme). Use `https://` only if your collector is configured with TLS.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.1.1 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading to v2.1.1, run `helm diff` on the **product charts** that consume it after updating their `lerian-common` dependency.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 2.1.1 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `2.1.1` and run `helm dependency update`, then upgrade the parent chart.
