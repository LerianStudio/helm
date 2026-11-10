<!-- {% raw %} -->
# Helm Upgrade from v9.7.1 to v9.7.2

## Topics

- **[Fixes](#fixes)**
  - [1. Ledger to tracer integration now supports gRPC-only transport](#1-ledger-to-tracer-integration-now-supports-grpc-only-transport)
  - [2. Tracer gRPC port always published on Service](#2-tracer-grpc-port-always-published-on-service)
  - [3. New validation for tracer seam credentials in single-tenant mode](#3-new-validation-for-tracer-seam-credentials-in-single-tenant-mode)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Ledger to tracer integration now supports gRPC-only transport

The ledger application version 4.2+ only supports gRPC transport when connecting to the tracer reservation seam. The `TRACER_TRANSPORT` environment variable now defaults to empty (which resolves to gRPC) and the chart will refuse to render if `rest` is explicitly set while the integration is enabled.

#### What changed

| Setting | v9.7.1 | v9.7.2 |
|---------|--------|--------|
| `ledger.configmap.TRACER_TRANSPORT` default | `"rest"` | `""` (empty, resolves to gRPC) |
| Accepted values when `TRACER_BASE_URL` is set | `"rest"` or `"grpc"` | `""` or `"grpc"` only |
| Behavior when `rest` is set with integration enabled | Renders (may fail at runtime on 4.2+) | Fails at render time with error |

#### New environment variables

Two new configuration keys have been added to `ledger.configmap`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TRACER_BASE_URL` | `""` | Ledger to tracer reservation seam endpoint. Empty keeps the integration off. With the bundled tracer, point it at the tracer gRPC Service port, e.g. `"midaz-tracer:4021"`. |
| `TRACER_TRANSPORT` | `""` | Ledger to tracer transport protocol. The 4.2+ ledger is gRPC-only: leave empty (resolves to gRPC) or set `"grpc"`. `"rest"` is refused at boot. |

**Before (v9.7.1):**

```yaml
ledger:
  configmap:
    # TRACER_TRANSPORT defaulted to "rest" internally
    # TRACER_BASE_URL was not explicitly documented
```

**After (v9.7.2):**

```yaml
ledger:
  configmap:
    # -- Ledger to tracer reservation seam. Empty keeps the integration off (the
    # ledger then ignores TRACER_TRANSPORT). With the bundled tracer, point it at
    # the tracer gRPC Service port, e.g. TRACER_BASE_URL: "midaz-tracer:4021".
    TRACER_BASE_URL: ""
    # -- Ledger to tracer transport. The 4.2+ ledger is gRPC-only: leave empty
    # (resolves to gRPC) or set "grpc". "rest" is refused at boot, so the render
    # fails when it is set together with TRACER_BASE_URL.
    TRACER_TRANSPORT: ""
```

#### Migration steps

1. **If you are not using the tracer integration** (`TRACER_BASE_URL` is empty or unset), no action is required. The ledger ignores `TRACER_TRANSPORT` when the integration is disabled.

2. **If you have `TRACER_TRANSPORT: "rest"` set and `TRACER_BASE_URL` is configured**, the chart will fail to render with the following error:

   ```
   ledger.configmap.TRACER_TRANSPORT=rest is not supported: the 4.2+ ledger reaches the tracer over gRPC only and refuses to boot with rest. Leave ledger.configmap.TRACER_TRANSPORT empty or set it to grpc
   ```

   **Action required:** Remove or change the value:

   ```yaml
   ledger:
     configmap:
       TRACER_BASE_URL: "midaz-tracer:4021"
       TRACER_TRANSPORT: ""  # or "grpc"
   ```

3. **If you are enabling the tracer integration for the first time**, set `TRACER_BASE_URL` to the tracer's gRPC Service endpoint and leave `TRACER_TRANSPORT` empty or set it to `"grpc"`:

   ```yaml
   ledger:
     configmap:
       TRACER_BASE_URL: "midaz-tracer:4021"
       TRACER_TRANSPORT: ""
   ```

> **Warning:** The ledger application version 4.2+ will refuse to boot if `TRACER_TRANSPORT` is set to `rest`. Ensure your configuration uses gRPC before upgrading.

### 2. Tracer gRPC port always published on Service

The tracer application always serves the reservation seam over gRPC (listening on `:4021` by default when `TRACER_GRPC_PORT` is unset). Previously, the chart only published the gRPC port on the Service and container when `tracer.configmap.TRACER_GRPC_PORT` was explicitly set. This caused confusion and prevented the ledger from reaching the tracer unless the port was manually configured.

#### What changed

| Component | v9.7.1 | v9.7.2 |
|-----------|--------|--------|
| Tracer container gRPC port | Published only if `TRACER_GRPC_PORT` set | Always published (default `4021`) |
| Tracer Service gRPC port | Published only if `TRACER_GRPC_PORT` set | Always published (default `4021`) |
| Tracer gRPC listen address | `:4021` (when `TRACER_GRPC_PORT` unset) | `:4021` (when `TRACER_GRPC_PORT` unset) |

**Before (v9.7.1):**

The tracer Deployment only exposed the gRPC port conditionally:

```yaml
ports:
  - name: http
    containerPort: 4020
    protocol: TCP
  {{- if .Values.tracer.configmap.TRACER_GRPC_PORT }}
  - name: grpc
    containerPort: {{ include "midaz-tracer.grpcPort" . }}
    protocol: TCP
  {{- end }}
```

The tracer Service only published the gRPC port conditionally:

```yaml
ports:
  - port: 4020
    targetPort: http
    protocol: TCP
    name: http
  {{- if .Values.tracer.configmap.TRACER_GRPC_PORT }}
  - port: {{ include "midaz-tracer.grpcPort" . }}
    targetPort: grpc
    protocol: TCP
    name: grpc
  {{- end }}
```

**After (v9.7.2):**

The tracer Deployment always exposes the gRPC port:

```yaml
ports:
  - name: http
    containerPort: 4020
    protocol: TCP
  - name: grpc
    containerPort: {{ include "midaz-tracer.grpcPort" . }}
    protocol: TCP
```

The tracer Service always publishes the gRPC port:

```yaml
ports:
  - port: 4020
    targetPort: http
    protocol: TCP
    name: http
  - port: {{ include "midaz-tracer.grpcPort" . }}
    targetPort: grpc
    protocol: TCP
    name: grpc
```

#### Operational impact

- **No action required for most users.** The tracer now correctly exposes its gRPC endpoint by default, matching the application's actual behavior.
- If you previously set `tracer.configmap.TRACER_GRPC_PORT` to work around this issue, you can now remove it and rely on the default `4021` port.
- The ledger can now reach the tracer at `midaz-tracer:4021` without additional configuration.

> **Note:** The `tracer.service.grpcPort` value (default `4021`) is now always used. If you have `tracer.configmap.TRACER_GRPC_PORT` set to a custom listen address (e.g., `:5000`), the chart will extract the numeric port and use it for both the container and Service, keeping them in sync.

### 3. New validation for tracer seam credentials in single-tenant mode

When the ledger's tracer integration is enabled (`TRACER_BASE_URL` is set), authentication is enabled (`PLUGIN_AUTH_ENABLED=true`), and the deployment is single-tenant (not multi-tenant), the ledger requires both `TRACER_M2M_CLIENT_ID` and `TRACER_M2M_CLIENT_SECRET` to be set. The ledger application will refuse to boot without these credentials.

The chart now validates these values at render time and fails early with a clear error message if they are missing.

#### What changed

| Validation | v9.7.1 | v9.7.2 |
|------------|--------|--------|
| `TRACER_M2M_CLIENT_ID` required when integration enabled + auth enabled + single-tenant | Not checked at render time | Checked at render time, fails if empty |
| `TRACER_M2M_CLIENT_SECRET` required when integration enabled + auth enabled + single-tenant | Not checked at render time | Checked at render time (unless `ledger.useExistingSecret` is true), fails if empty |

#### New validation errors

If the tracer integration is enabled, authentication is enabled, and the deployment is single-tenant, the chart will fail to render with one of the following errors:

**Missing `TRACER_M2M_CLIENT_ID`:**

```
ledger.configmap.TRACER_M2M_CLIENT_ID is required when TRACER_BASE_URL is set and PLUGIN_AUTH_ENABLED=true (single-tenant): the ledger refuses to boot without the reservation seam token identity
```

**Missing `TRACER_M2M_CLIENT_SECRET` (when not using `ledger.useExistingSecret`):**

```
ledger.secrets.TRACER_M2M_CLIENT_SECRET is required when TRACER_BASE_URL is set and PLUGIN_AUTH_ENABLED=true (single-tenant): the ledger refuses to boot without the reservation seam token identity (or provide it through ledger.useExistingSecret)
```

#### Migration steps

1. **If you are not using the tracer integration** (`TRACER_BASE_URL` is empty), no action is required.

2. **If you are using the tracer integration with authentication disabled** (`PLUGIN_AUTH_ENABLED=false`), no action is required.

3. **If you are using the tracer integration with authentication enabled in multi-tenant mode**, no action is required. Multi-tenant deployments read the identity per tenant from `M2M_SECRETS_BACKEND`.

4. **If you are using the tracer integration with authentication enabled in single-tenant mode**, ensure both credentials are set:

   ```yaml
   ledger:
     configmap:
       TRACER_BASE_URL: "midaz-tracer:4021"
       TRACER_M2M_CLIENT_ID: "your-client-id"
     secrets:
       TRACER_M2M_CLIENT_SECRET: "your-client-secret"
   ```

   Alternatively, if you manage secrets externally:

   ```yaml
   ledger:
     useExistingSecret: true
     existingSecretName: "your-external-secret"
     configmap:
       TRACER_BASE_URL: "midaz-tracer:4021"
       TRACER_M2M_CLIENT_ID: "your-client-id"
   ```

> **Important:** The chart cannot validate `TRACER_M2M_CLIENT_SECRET` when `ledger.useExistingSecret` is true. Ensure your external secret includes the `TRACER_M2M_CLIENT_SECRET` key, or the ledger will fail to boot.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.7.2 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.7.2 -n midaz
```
<!-- {% endraw %} -->
