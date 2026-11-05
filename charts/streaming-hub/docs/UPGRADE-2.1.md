# Helm Upgrade from v2.0.4 to v2.1.0

## Topics

- **[Features](#features)**
  - [1. License file mode support](#1-license-file-mode-support)
- **[Configuration Reference](#configuration-reference)**
  - [License file configuration](#license-file-configuration)
- **[Migration Steps](#migration-steps)**
  - [Step 1: Assess your license delivery method](#step-1-assess-your-license-delivery-method)
  - [Step 2: (Optional) Migrate to license file mode](#step-2-optional-migrate-to-license-file-mode)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Features

### 1. License file mode support

The chart now supports an alternative license delivery mechanism: a signed license file mounted from a Kubernetes Secret, instead of the `LICENSE_KEY` environment variable.

**What changed:**

| Setting | v2.0.4 | v2.1.0 |
|---------|--------|--------|
| License delivery | `LICENSE_KEY` secret key only | `LICENSE_KEY` (default) or signed file via `streamingHub.licenseFile.existingSecret` |
| License file mount path | Not available | `/etc/lerian/license/license` (read-only directory mount) |
| `LICENSE_KEY` requirement | Always required | Optional when `licenseFile.existingSecret` is set |

**Why it matters:**

- **Rotation without restart:** The license file is mounted as a directory (not `subPath`), so Kubernetes propagates Secret updates to running pods. When the license expires, operators can rotate the file by updating the Secret without redeploying the application.
- **Compatibility:** License file mode requires an application image built with `lib-license-go` v5 or later. Older images will ignore the `LICENSE_FILE_PATH` environment variable and continue to require `LICENSE_KEY`.
- **Coexistence:** Both modes can coexist during migration. If both `LICENSE_KEY` and `LICENSE_FILE_PATH` are present, the application's license library determines precedence (typically file mode wins).

**Configuration:**

```yaml
streamingHub:
  licenseFile:
    existingSecret: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.licenseFile.existingSecret` | `""` | Name of an existing Secret containing the signed license file (key: `license`) |

**Behavior:**

When `streamingHub.licenseFile.existingSecret` is set to a non-empty string:

1. The chart mounts the specified Secret as a read-only volume at `/etc/lerian/license` on every Deployment (all, ingest, delivery).
2. The `LICENSE_FILE_PATH` environment variable is set to `/etc/lerian/license/license`.
3. The `LICENSE_KEY` secret key becomes optional (marked `optional: true` in the `secretKeyRef`). If the key is missing from the Secret, the container will start successfully and rely on the file.

**New environment variables:**

| Variable | Value | Description |
|----------|-------|-------------|
| `LICENSE_FILE_PATH` | `/etc/lerian/license/license` | Path to the signed license file (set only when `licenseFile.existingSecret` is configured) |

**Example configuration (license file mode):**

```yaml
streamingHub:
  useExistingSecret: true
  existingSecretName: "streaming-hub-credentials"
  licenseFile:
    existingSecret: "streaming-hub-license"
```

The `streaming-hub-license` Secret must contain:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: streaming-hub-license
  namespace: streaming-hub
type: Opaque
data:
  license: <base64-encoded signed license file>
```

> **Important:** The Secret key must be exactly `license`. The chart template explicitly maps this key to the mount path `license` inside the container.

**Example configuration (traditional LICENSE_KEY mode, unchanged):**

```yaml
streamingHub:
  useExistingSecret: false
  secrets:
    LICENSE_KEY: "your-license-key-string"
```

Or with an existing Secret:

```yaml
streamingHub:
  useExistingSecret: true
  existingSecretName: "streaming-hub-credentials"
```

Where `streaming-hub-credentials` contains the `LICENSE_KEY` key.

**Template changes:**

The Deployment template now conditionally injects the license file volume and mount:

**Before (v2.0.4):**

```yaml
env:
  - name: LICENSE_KEY
    valueFrom:
      secretKeyRef:
        name: streaming-hub
        key: LICENSE_KEY
```

**After (v2.1.0):**

```yaml
env:
  - name: LICENSE_FILE_PATH
    value: /etc/lerian/license/license  # Only when licenseFile.existingSecret is set
  - name: LICENSE_KEY
    valueFrom:
      secretKeyRef:
        name: streaming-hub
        key: LICENSE_KEY
        optional: true  # Only when licenseFile.existingSecret is set
volumeMounts:
  - name: license-file
    mountPath: /etc/lerian/license
    readOnly: true
volumes:
  - name: license-file
    secret:
      secretName: streaming-hub-license
      defaultMode: 0444
      items:
        - key: license
          path: license
```

> **Note:** The volume mount uses `mountPath` (directory mount), not `subPath`, to ensure Secret updates propagate to the pod without a restart. The `defaultMode: 0444` sets the file as world-readable (required for the non-root user `65532`).

**Secret contract update:**

The `streamingHub.existingSecretName` contract has been relaxed when license file mode is enabled:

**Before (v2.0.4):**

The external Secret **must** contain the keys:
- `STREAMING_HUB_POSTGRES_DSN` (required)
- `STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY` (required)
- `LICENSE_KEY` (required)

**After (v2.1.0):**

The external Secret **must** contain the keys:
- `STREAMING_HUB_POSTGRES_DSN` (required)
- `STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY` (required)
- `LICENSE_KEY` (required **unless** `streamingHub.licenseFile.existingSecret` is set)

The updated error message in the `streaming-hub.secretName` helper now reads:

```
ERROR: streamingHub.existingSecretName is required when streamingHub.useExistingSecret=true. 
The referenced Secret MUST carry the keys STREAMING_HUB_POSTGRES_DSN and 
STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY, plus LICENSE_KEY unless 
streamingHub.licenseFile.existingSecret is set (file mode, which needs an image on 
lib-license-go v5) — the Deployments consume them via explicit secretKeyRefs, and a 
Secret missing a required one fails container creation (CreateContainerConfigError) 
instead of starting the app.
```

---

## Configuration Reference

### License file configuration

```yaml
streamingHub:
  licenseFile:
    existingSecret: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.licenseFile.existingSecret` | `""` | Name of an existing Secret containing the signed license file. The Secret must have a key named `license` with the base64-encoded signed license file as its value. When set, the `LICENSE_KEY` secret key becomes optional. |

**Related configuration:**

```yaml
streamingHub:
  useExistingSecret: false
  existingSecretName: ""
  secrets:
    LICENSE_KEY: ""
```

| Flag | Default | Description |
|------|---------|-------------|
| `streamingHub.useExistingSecret` | `false` | Use an external Secret instead of chart-managed secrets |
| `streamingHub.existingSecretName` | `""` | Name of the external Secret (required when `useExistingSecret: true`) |
| `streamingHub.secrets.LICENSE_KEY` | `""` | License key string (chart-managed secret path only; ignored when `useExistingSecret: true`) |

---

## Migration Steps

### Step 1: Assess your license delivery method

Determine whether you want to adopt license file mode or continue using the `LICENSE_KEY` environment variable.

**Continue with LICENSE_KEY (no action required):**

If your current configuration uses `LICENSE_KEY` (either chart-managed or via `useExistingSecret`), the upgrade is transparent. The chart will continue to inject `LICENSE_KEY` as before, and the application will honor it.

```yaml
# Existing configuration (no changes needed)
streamingHub:
  useExistingSecret: true
  existingSecretName: "streaming-hub-credentials"
```

**Adopt license file mode:**

If you want to enable license file rotation without pod restarts, proceed to Step 2.

> **Important:** Verify that your application image is built with `lib-license-go` v5 or later. Older images do not recognize the `LICENSE_FILE_PATH` environment variable and will fail to start if `LICENSE_KEY` is missing.

### Step 2: (Optional) Migrate to license file mode

#### Option 1: Coexist both modes during migration

Provision the license file Secret while keeping `LICENSE_KEY` in place. This allows you to validate the file mount before removing the key.

**Step 2a: Create the license file Secret**

Obtain your signed license file (e.g., `license.signed`) and create a Secret:

```bash
kubectl create secret generic streaming-hub-license \
  --from-file=license=./license.signed \
  -n streaming-hub
```

**Step 2b: Update your values to reference the license file Secret**

```yaml
streamingHub:
  useExistingSecret: true
  existingSecretName: "streaming-hub-credentials"  # Still contains LICENSE_KEY
  licenseFile:
    existingSecret: "streaming-hub-license"
```

**Step 2c: Upgrade the chart**

```bash
helm upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm \
  --version 2.1.0 \
  -n streaming-hub \
  -f values.yaml
```

**Step 2d: Verify the application starts and reads the license file**

Check the application logs for license validation messages. The application should log that it successfully loaded the license from `/etc/lerian/license/license`.

```bash
kubectl logs -n streaming-hub deployment/streaming-hub --tail=50 | grep -i license
```

**Step 2e: (Optional) Remove LICENSE_KEY from the credentials Secret**

Once you confirm the application is using the file, you can remove the `LICENSE_KEY` key from the `streaming-hub-credentials` Secret:

```bash
kubectl create secret generic streaming-hub-credentials \
  --from-literal=STREAMING_HUB_POSTGRES_DSN="postgresql://..." \
  --from-literal=STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY="..." \
  --dry-run=client -o yaml | kubectl apply -f -
```

The pods will continue running because `LICENSE_KEY` is now marked `optional: true` in the secret reference.

#### Option 2: Migrate directly to file-only mode

If you are confident in your license file and application version, you can remove `LICENSE_KEY` immediately.

**Step 2a: Create the license file Secret**

```bash
kubectl create secret generic streaming-hub-license \
  --from-file=license=./license.signed \
  -n streaming-hub
```

**Step 2b: Update your credentials Secret to remove LICENSE_KEY**

```bash
kubectl create secret generic streaming-hub-credentials \
  --from-literal=STREAMING_HUB_POSTGRES_DSN="postgresql://..." \
  --from-literal=STREAMING_HUB_DASHBOARD_CURSOR_HMAC_KEY="..." \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Step 2c: Update your values**

```yaml
streamingHub:
  useExistingSecret: true
  existingSecretName: "streaming-hub-credentials"
  licenseFile:
    existingSecret: "streaming-hub-license"
```

**Step 2d: Upgrade the chart**

```bash
helm upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm \
  --version 2.1.0 \
  -n streaming-hub \
  -f values.yaml
```

> **Warning:** If the license file is invalid or the application image does not support `LICENSE_FILE_PATH`, the pods will fail to start with a license validation error. Always test in a non-production environment first.

---

## Preview changes before upgrading

```bash
helm diff upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm -n streaming-hub --version 2.1.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade streaming-hub oci://ghcr.io/lerianstudio/streaming-hub-helm -n streaming-hub --version 2.1.0
```
