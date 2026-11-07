# Helm Upgrade from v2.3.0 to v2.3.1

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Removal of TLS configuration from main HTTP server](#1-removal-of-tls-configuration-from-main-http-server)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `plugin-br-payments` chart upgrade from `2.3.0` to `2.3.1`. The application version remains `1.2.0`; the chart bump to `2.3.1` is a patch release that removes TLS configuration options from the main HTTP server. The application now serves plain HTTP on its main port and expects TLS termination to occur at the Ingress or service mesh layer.

Existing deployments that set `SERVER_TLS_CERT_FILE` or `SERVER_TLS_KEY_FILE` in their values overlay must remove these keys before upgrading. The chart will fail fast at upgrade time if these keys are still present.

## Fixes

### 1. Removal of TLS configuration from main HTTP server

The chart no longer supports TLS termination at the application layer. Three environment variables have been removed from the ConfigMap template:

- `TLS_TERMINATED_UPSTREAM`
- `SERVER_TLS_CERT_FILE`
- `SERVER_TLS_KEY_FILE`

The application binary now serves plain HTTP on its main port. TLS termination must be handled by the Ingress controller or service mesh.

**Before (v2.3.0):**

```yaml
data:
  TLS_TERMINATED_UPSTREAM: "true"
  SERVER_TLS_CERT_FILE: "/path/to/cert.pem"
  SERVER_TLS_KEY_FILE: "/path/to/key.pem"
```

**After (v2.3.1):**

These keys are no longer rendered in the ConfigMap. The chart will reject any values overlay that includes `SERVER_TLS_CERT_FILE` or `SERVER_TLS_KEY_FILE` with an explicit error message:

```
ERROR: app.configmap.SERVER_TLS_CERT_FILE is no longer read by plugin-br-payments (the main port serves plain HTTP; terminate TLS at the Ingress or mesh).
   Remove it from your values overlay.
```

```
ERROR: app.configmap.SERVER_TLS_KEY_FILE is no longer read by plugin-br-payments (the main port serves plain HTTP; terminate TLS at the Ingress or mesh).
   Remove it from your values overlay.
```

**Operational impact:**

If your deployment previously set `SERVER_TLS_CERT_FILE` or `SERVER_TLS_KEY_FILE` in `app.configmap`, the application was attempting to serve HTTPS on its main port. After upgrading to v2.3.1, the application will serve plain HTTP. You must ensure TLS termination is configured at the Ingress or service mesh layer before upgrading.

If you rely on end-to-end encryption between the Ingress and the application pod, you must reconfigure your architecture to terminate TLS at the Ingress or enable mTLS via a service mesh (e.g., Istio, Linkerd).

> **Warning:** If your Ingress is configured to forward HTTPS traffic directly to the application pod (e.g., `backend.protocol: HTTPS` in an AWS ALB Ingress annotation), you must change it to HTTP before upgrading. The application will no longer accept TLS connections on its main port.

> **Important:** The `TLS_TERMINATED_UPSTREAM` flag has also been removed. If you previously set this to `"false"` to enable application-layer TLS, that configuration is no longer supported. The application now assumes TLS is always terminated upstream.

## Configuration Changes

| Setting | v2.3.0 | v2.3.1 |
|---------|--------|--------|
| `app.configmap.TLS_TERMINATED_UPSTREAM` | `"true"` (default) | removed |
| `app.configmap.SERVER_TLS_CERT_FILE` | optional | removed (rejected by chart) |
| `app.configmap.SERVER_TLS_KEY_FILE` | optional | removed (rejected by chart) |

No new configuration values were added. The chart now enforces that `SERVER_TLS_CERT_FILE` and `SERVER_TLS_KEY_FILE` must not be present in `app.configmap`.

## Migration Steps

1. Review your values overlay for any references to `SERVER_TLS_CERT_FILE`, `SERVER_TLS_KEY_FILE`, or `TLS_TERMINATED_UPSTREAM` under `app.configmap`. Remove all three keys if present.

2. Verify your Ingress configuration terminates TLS and forwards plain HTTP to the application Service. If you use an Ingress controller with backend protocol annotations (e.g., AWS ALB, NGINX), ensure the backend protocol is set to HTTP, not HTTPS.

   Example for AWS ALB Ingress:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     annotations:
       alb.ingress.kubernetes.io/backend-protocol: HTTP
   ```

   Example for NGINX Ingress:

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     annotations:
       nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
   ```

3. If you previously mounted TLS certificate and key files into the application pod via `volumeMounts` or `volumes`, remove those mounts from your values overlay. The application will no longer read them.

4. **(Optional)** If you require end-to-end encryption between the Ingress and the application pod, configure a service mesh with mTLS (e.g., Istio, Linkerd) before upgrading.

5. Run the upgrade command during a maintenance window (see [Command to upgrade](#command-to-upgrade)).

6. Verify all pods are running and healthy after the upgrade:

   ```bash
   kubectl get pods -n <namespace>
   ```

7. Confirm the application is serving HTTP on its main port by checking the Service and pod logs:

   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=plugin-br-payments-helm --tail=50
   ```

   You should see log entries indicating the HTTP server started on the configured port (default `8080`), with no references to TLS certificate loading.

8. Test an HTTP request to the application through the Ingress to verify TLS termination is working correctly:

   ```bash
   curl -v https://<your-ingress-host>/health
   ```

   The TLS handshake should complete at the Ingress, and the application should respond over plain HTTP.

> **Note:** The upgrade triggers a rolling restart of the plugin pods. Depending on your replica count and readiness probe configuration, this may cause brief request handling interruptions.

## Preview changes before upgrading

```bash
helm diff upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.3.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade my-payments oci://ghcr.io/lerianstudio/plugin-br-payments-helm --namespace midaz-plugins --version 2.3.1
```
