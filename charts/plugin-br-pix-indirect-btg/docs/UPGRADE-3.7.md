# Helm Upgrade from v3.6.0 to v3.7.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Outbound client mTLS to BTG API](#1-outbound-client-mtls-to-btg-api)
- **[Configuration Reference](#configuration-reference)**
  - [mTLS configuration block](#mtls-configuration-block)
  - [Environment variables](#environment-variables)
- **[Migration Steps](#migration-steps)**
  - [Option 1: Keep mTLS disabled (default)](#option-1-keep-mtls-disabled-default)
  - [Option 2: Enable mTLS with chart-managed Secret](#option-2-enable-mtls-with-chart-managed-secret)
  - [Option 3: Enable mTLS with externally-managed Secret](#option-3-enable-mtls-with-externally-managed-secret)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that adds support for outbound client mTLS when calling the BTG API. The application version bumps from `1.8.0` to `1.9.0` across all five components (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`). The new `mtls` configuration block is **disabled by default**, so existing deployments will continue to work without changes.

The expected upgrade path is an in-place Helm upgrade. Operators who need to enable mTLS for BTG API calls must supply client certificates via values or an external Secret before or during the upgrade.

## Features

### 1. Outbound client mTLS to BTG API

The chart now supports mutual TLS authentication for outbound calls to the BTG API. This feature is shared by the `pix` and `reconciliation` components, which communicate directly with BTG. The `inbound`, `outbound`, and `schedule` components do not call BTG and are unaffected by this feature, but they receive the same application version bump.

**What changed:**

- A new top-level `mtls` configuration block was added to `values.yaml` with an `enabled` flag (default: `false`)
- When enabled, the chart mounts a client certificate and private key into the `pix` and `reconciliation` pods
- The certificate material can be supplied inline (chart-managed Secret) or via an externally-managed Secret (cert-manager, External Secrets, Vault CSI, manual)
- The application reads the certificate at startup and uses it for all BTG API calls
- Four new environment variables are injected into the `pix` and `reconciliation` ConfigMaps when `mtls.enabled` is `true`

**Why it matters:**

BTG may require client certificate authentication for production API access. This feature allows operators to configure mTLS without forking the chart or manually patching deployments.

**Operational impact:**

- **If you leave `mtls.enabled: false` (default):** No impact. The upgrade proceeds normally and no mTLS configuration is applied.
- **If you enable `mtls.enabled: true`:** The `pix` and `reconciliation` deployments will restart with the new certificate volume mounted. The application will attempt to load the client certificate at startup. If the certificate is invalid or missing, the pods will fail to start.

> **Important:** The application snapshots the certificate at startup and does not hot-reload it. Rotating the certificate Secret requires a pod restart (either by changing the Secret data when using chart-managed mode, or by manually rolling the deployment when using externally-managed mode).

**Security considerations:**

- The certificate Secret is mounted read-only at mode `0440` (owner and group read, no write, no other)
- The pod's `fsGroup` is set to `1000` (matching the application's `runAsGroup`) so the non-root application user can read the group-readable key
- The certificate files are projected into the pod at `/etc/btg/mtls` by default (configurable via `mtls.mountPath`)
- Only the specified certificate, key, and optional CA file are projected from the Secret — other keys in the Secret are not mounted

## Configuration Reference

### mTLS configuration block

The new `mtls` block is added at the top level of `values.yaml`, immediately after the `global` block and before the `pix` block.

| Setting | Default | Description |
|---------|---------|-------------|
| `mtls.enabled` | `false` | Enable outbound client mTLS for BTG API calls |
| `mtls.secretName` | `""` | Name of the Secret holding the certificate. Defaults to `<release-fullname>-mtls` if empty |
| `mtls.tls.crt` | `""` | Client certificate PEM. Set this to have the chart create the Secret. Leave empty to use an externally-managed Secret |
| `mtls.tls.key` | `""` | Private key PEM. Required when `tls.crt` is set |
| `mtls.ca.crt` | `""` | Optional CA certificate PEM for verifying BTG's server certificate. Leave empty to use system roots |
| `mtls.mountPath` | `"/etc/btg/mtls"` | Mount path for the certificate volume inside the pod |
| `mtls.certFileName` | `"tls.crt"` | Key in the Secret and file name for the client certificate |
| `mtls.keyFileName` | `"tls.key"` | Key in the Secret and file name for the private key |
| `mtls.caFileName` | `""` | Key in the Secret and file name for the CA certificate. Leave empty to omit |
| `mtls.fsGroup` | `1000` | Pod `fsGroup` applied so the non-root app can read the group-readable key |

**Example configuration (chart-managed Secret):**

```yaml
mtls:
  enabled: true
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    MIIDXTCCAkWgAwIBAgIJAKZ...
    -----END CERTIFICATE-----
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0...
    -----END PRIVATE KEY-----
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    MIIDdzCCAl+gAwIBAgIEAgAA...
    -----END CERTIFICATE-----
```

**Example configuration (externally-managed Secret):**

```yaml
mtls:
  enabled: true
  secretName: btg-client-cert
```

> **Note:** When `mtls.tls.crt` is set, the chart creates a Secret named `<release-fullname>-mtls` (or the value of `mtls.secretName` if overridden). When `mtls.tls.crt` is empty, the chart expects a Secret named `mtls.secretName` to already exist.

### Environment variables

When `mtls.enabled` is `true`, the following environment variables are added to the `pix` and `reconciliation` ConfigMaps:

| Variable | Value | Description |
|----------|-------|-------------|
| `BTG_OUTBOUND_MTLS_ENABLED` | `"true"` | Enables client mTLS in the application |
| `CLIENT_TLS_CERT_FILE` | `"/etc/btg/mtls/tls.crt"` | Path to the client certificate file |
| `CLIENT_TLS_KEY_FILE` | `"/etc/btg/mtls/tls.key"` | Path to the private key file |
| `CLIENT_TLS_CA_FILE` | `"/etc/btg/mtls/ca.crt"` | Path to the CA certificate file (only set if `mtls.ca.crt` or `mtls.caFileName` is configured) |

The paths are constructed from `mtls.mountPath` and the corresponding file name fields. If you override `mtls.mountPath` or the file name fields, the environment variables will reflect those overrides.

**Before (v3.6.0):**

These environment variables did not exist. The `pix` and `reconciliation` ConfigMaps contained only the existing application configuration.

**After (v3.7.0):**

When `mtls.enabled: true`, the ConfigMaps include the mTLS configuration block:

```yaml
data:
  # ... existing configuration ...
  BTG_OUTBOUND_MTLS_ENABLED: "true"
  CLIENT_TLS_CERT_FILE: "/etc/btg/mtls/tls.crt"
  CLIENT_TLS_KEY_FILE: "/etc/btg/mtls/tls.key"
  CLIENT_TLS_CA_FILE: "/etc/btg/mtls/ca.crt"
```

## Migration Steps

### Option 1: Keep mTLS disabled (default)

If you do not need client mTLS for BTG API calls, no action is required. The upgrade will proceed normally and the new `mtls` configuration will remain disabled.

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify all pods are running and healthy after the upgrade.

```bash
kubectl get pods -n <release-namespace>
```

4. Check service logs for any startup errors.

```bash
kubectl logs -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
```

> **Note:** The upgrade triggers a rolling restart of all five deployments (`pix`, `inbound`, `outbound`, `reconciliation`, `schedule`) because the application version changes from `1.8.0` to `1.9.0`. Depending on your replica count, this may cause brief service interruptions.

### Option 2: Enable mTLS with chart-managed Secret

If you want the chart to create and manage the certificate Secret, supply the certificate material inline via `mtls.tls.crt` and `mtls.tls.key`.

1. Obtain your client certificate and private key in PEM format.
2. Create a custom values file or add the following to your existing values:

```yaml
mtls:
  enabled: true
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    MIIDXTCCAkWgAwIBAgIJAKZ...
    -----END CERTIFICATE-----
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0...
    -----END PRIVATE KEY-----
```

3. If BTG requires a specific CA to verify its server certificate, add it:

```yaml
mtls:
  enabled: true
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    ...
    -----END PRIVATE KEY-----
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
```

4. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
5. Run the upgrade command with your custom values file:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.7.0 -n <release-namespace> -f custom-values.yaml
```

6. Verify the Secret was created:

```bash
kubectl get secret -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg
```

7. Verify the `pix` and `reconciliation` pods are running and have the certificate volume mounted:

```bash
kubectl describe pod -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg
kubectl describe pod -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg-worker-reconciliation
```

8. Check the logs for successful certificate loading:

```bash
kubectl logs -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
kubectl logs -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg-worker-reconciliation --tail=50
```

> **Warning:** The certificate and key are stored in the Helm release values. If you use a GitOps tool, ensure the values file is encrypted (e.g., using SOPS, Sealed Secrets, or a secret management tool like ArgoCD Vault Plugin).

> **Note:** When the chart manages the Secret, changing `mtls.tls.crt` or `mtls.tls.key` in a subsequent upgrade will trigger a pod rollout automatically (via a checksum annotation). You do not need to manually restart the pods.

### Option 3: Enable mTLS with externally-managed Secret

If you prefer to manage the certificate Secret outside of Helm (e.g., using cert-manager, External Secrets, Vault CSI, or manual creation), leave `mtls.tls.crt` empty and point `mtls.secretName` to your existing Secret.

1. Create the Secret in the same namespace as the chart, with keys matching the expected file names:

```bash
kubectl create secret generic btg-client-cert \
  --from-file=tls.crt=/path/to/client.crt \
  --from-file=tls.key=/path/to/client.key \
  --from-file=ca.crt=/path/to/ca.crt \
  -n <release-namespace>
```

For the common cert + key only case (no CA), `kubectl create secret tls` is more idiomatic — it produces a `kubernetes.io/tls` Secret whose keys are already `tls.crt` / `tls.key` (matching the chart defaults):

```bash
kubectl create secret tls btg-client-cert \
  --cert=/path/to/client.crt \
  --key=/path/to/client.key \
  -n <release-namespace>
```

2. Add the following to your custom values file:

```yaml
mtls:
  enabled: true
  secretName: btg-client-cert
```

3. If your Secret uses different key names, override the file name fields:

```yaml
mtls:
  enabled: true
  secretName: btg-client-cert
  certFileName: client.crt
  keyFileName: client.key
  caFileName: ca-bundle.crt
```

4. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
5. Run the upgrade command with your custom values file:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.7.0 -n <release-namespace> -f custom-values.yaml
```

6. Verify the `pix` and `reconciliation` pods are running and have the certificate volume mounted:

```bash
kubectl describe pod -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg
kubectl describe pod -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg-worker-reconciliation
```

7. Check the logs for successful certificate loading:

```bash
kubectl logs -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg --tail=50
kubectl logs -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg-worker-reconciliation --tail=50
```

> **Important:** When using an externally-managed Secret, rotating the certificate does **not** automatically trigger a pod rollout. You must manually restart the pods after updating the Secret:

```bash
kubectl rollout restart deployment -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg
kubectl rollout restart deployment -n <release-namespace> -l app.kubernetes.io/name=plugin-br-pix-indirect-btg-worker-reconciliation
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.7.0 -n <release-namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

> The chart is published to both registries — use whichever you prefer:
> `oci://ghcr.io/lerianstudio/plugin-br-pix-indirect-btg-helm` or
> `oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm`.
> The commands in this guide use the Docker Hub mirror.

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.7.0 -n <release-namespace>
```
