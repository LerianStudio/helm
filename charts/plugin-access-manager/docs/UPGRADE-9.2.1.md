# Helm Upgrade from v9.2.0 to v9.2.1

# Topics

- **[Fixes](#fixes)**
  - [1. Init Container Image Change for TLS Compatibility](#1-init-container-image-change-for-tls-compatibility)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Init Container Image Change for TLS Compatibility

The auth service's `wait-for-dependencies` init container has been updated to use `curlimages/curl:8.10.1` instead of `busybox`, and the health check command has been changed from `wget` to `curl`.

**What changed:**

The init container that waits for the authorizer backend to be ready now uses a curl-based image instead of busybox.

**Before (v9.2.0):**

```yaml
# auth/deployment.yaml
initContainers:
  - name: wait-for-dependencies
    securityContext:
      {{- toYaml .Values.auth.securityContext | nindent 12 }}
    image: busybox
    envFrom:
    - configMapRef:
        name: {{ include "plugin-auth.fullname" . }}
    command:
      - /bin/sh
      - -c
      - |
        #!/bin/bash
        until wget --spider -q "$AUTHORIZER_ADDRESS/api/health"; do
          echo "Wait for backend...";
          sleep 5;
        done;
```

**After (v9.2.1):**

```yaml
# auth/deployment.yaml
initContainers:
  - name: wait-for-dependencies
    securityContext:
      {{- toYaml .Values.auth.securityContext | nindent 12 }}
    # curl, not busybox wget: busybox's wget cannot complete a TLS
    # handshake against SNI-routed endpoints (alert 40), so an https
    # AUTHORIZER_ADDRESS -- required by the 3.3.0 JWKS TLS gate outside
    # dev/staging/local ENV_NAME -- wedged this init forever.
    image: curlimages/curl:8.10.1
    envFrom:
    - configMapRef:
        name: {{ include "plugin-auth.fullname" . }}
    command:
      - /bin/sh
      - -c
      - |
        until curl -sf -o /dev/null "$AUTHORIZER_ADDRESS/api/health"; do
          echo "Wait for backend...";
          sleep 5;
        done;
```

**Why this matters:**

- **TLS/SNI compatibility:** Busybox's `wget` implementation cannot complete TLS handshakes against SNI-routed endpoints, causing TLS alert 40 errors
- **HTTPS AUTHORIZER_ADDRESS support:** When `AUTHORIZER_ADDRESS` uses HTTPS (required by application version 3.3.0+ JWKS TLS requirements in production environments), the busybox-based init container would hang indefinitely
- **Production readiness:** This fix ensures the auth service can start successfully when the authorizer backend is accessed over HTTPS with SNI routing

**Impact on operators:**

This is a transparent fix that requires no configuration changes. The init container will now successfully perform health checks against HTTPS authorizer endpoints.

| Component | v9.2.0 | v9.2.1 |
|-----------|--------|--------|
| Init container image | `busybox` | `curlimages/curl:8.10.1` |
| Health check command | `wget --spider -q` | `curl -sf -o /dev/null` |

**Default behavior:**

The upgrade will automatically pull the new `curlimages/curl:8.10.1` image. No values.yaml changes are required.

> **Note:** If you have custom image pull policies or private registries, ensure the `curlimages/curl:8.10.1` image is accessible from your cluster.

> **Important:** This fix is critical for deployments where `AUTHORIZER_ADDRESS` uses HTTPS with SNI routing. Without this change, the auth service pods may fail to start in production environments running application version 3.3.0 or later.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.1 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.2.1 -n plugin-access-manager
```
