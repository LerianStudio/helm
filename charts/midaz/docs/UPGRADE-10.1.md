<!-- {% raw %} -->
# Helm Upgrade from v10.0.5 to v10.1.0

## Topics

- **[Features](#features)**
  - [1. Product license key support for ledger and tracer](#1-product-license-key-support-for-ledger-and-tracer)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Product license key support for ledger and tracer

This release adds `LICENSE_KEY` secret fields for the `ledger` and `tracer` services. Both services now require a valid license key to boot. The chart templates conditionally include the `LICENSE_KEY` environment variable in the respective Secrets when the value is set.

#### What changed

| Service | Setting | v10.0.5 | v10.1.0 | Required |
|---------|---------|---------|---------|----------|
| ledger | `ledger.secrets.LICENSE_KEY` | (not present) | `""` (empty string) | Yes |
| tracer | `tracer.secrets.LICENSE_KEY` | (not present) | `""` (empty string) | Yes |

The default value for both fields is an empty string. According to the inline comments in `values.yaml`, **the ledger and tracer refuse to boot when `LICENSE_KEY` is empty**.

The templates add the `LICENSE_KEY` to the respective Secrets only when the value is non-empty:

**ledger Secret (charts/midaz/templates/ledger/secrets.yaml):**

```yaml
# LICENSE_KEY (required by the product; empty makes the ledger refuse to boot)
{{- if .Values.ledger.secrets.LICENSE_KEY }}
LICENSE_KEY: {{ .Values.ledger.secrets.LICENSE_KEY | b64enc | quote }}
{{- end }}
```

**tracer Secret (charts/midaz/templates/tracer/secrets.yaml):**

```yaml
# LICENSE_KEY (required by the product; empty makes the tracer refuse to boot)
{{- if .Values.tracer.secrets.LICENSE_KEY }}
LICENSE_KEY: {{ .Values.tracer.secrets.LICENSE_KEY | b64enc | quote }}
{{- end }}
```

#### Operational impact

- **Pods will not start without a license key.** If you upgrade without setting `LICENSE_KEY` for the ledger or tracer, the respective pods will fail to start. The application logs will indicate that the license key is missing or invalid.
- Pods roll once. The chart version is part of the `helm.sh/chart` label in the pod templates, so any chart version bump, including this one, triggers a rolling restart of the Midaz pods.
- The ledger migrations Job runs as a `pre-upgrade` hook on every upgrade, including this one.
- The `LICENSE_KEY` is stored in the Kubernetes Secret for each service and base64-encoded by the template.

#### Action required

> **Warning:** You must provide a valid `LICENSE_KEY` for both the ledger and tracer services before upgrading to v10.1.0. Without it, the pods will fail to start.

##### Step 1: Obtain your license keys

Contact your Midaz support team or account manager to obtain valid license keys for the ledger and tracer services.

##### Step 2: Add the license keys to your values file

Add the `LICENSE_KEY` fields under the `secrets` section for both services:

```yaml
ledger:
  secrets:
    LICENSE_KEY: "your-ledger-license-key-here"

tracer:
  secrets:
    LICENSE_KEY: "your-tracer-license-key-here"
```

Replace `your-ledger-license-key-here` and `your-tracer-license-key-here` with the actual license keys provided by your vendor.

##### Step 3: Upgrade the chart

Run the upgrade command with your updated values file:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.1.0 -n midaz -f values.yaml
```

Alternatively, pass the license keys directly via `--set`:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.1.0 -n midaz \
  --set ledger.secrets.LICENSE_KEY="your-ledger-license-key-here" \
  --set tracer.secrets.LICENSE_KEY="your-tracer-license-key-here"
```

#### Verification after upgrade

Check that the ledger and tracer pods are running:

```bash
kubectl get pods -n midaz -l app.kubernetes.io/name=midaz-ledger
kubectl get pods -n midaz -l app.kubernetes.io/name=midaz-tracer
```

Both should show `Running` status. If a pod is in `CrashLoopBackOff` or `Error`, check the logs:

```bash
kubectl logs -n midaz -l app.kubernetes.io/name=midaz-ledger --tail=50
kubectl logs -n midaz -l app.kubernetes.io/name=midaz-tracer --tail=50
```

Look for messages indicating a missing or invalid license key. If the license key is incorrect, update your values file and run the upgrade command again.

Verify that the `LICENSE_KEY` is present in the Secrets:

```bash
kubectl get secret -n midaz midaz-ledger-secrets -o jsonpath='{.data.LICENSE_KEY}' | base64 -d
kubectl get secret -n midaz midaz-tracer-secrets -o jsonpath='{.data.LICENSE_KEY}' | base64 -d
```

The output should match the license keys you provided (without the base64 encoding).

## Configuration Reference

The following new secret fields are available in v10.1.0:

| Field | Service | Type | Default | Description |
|-------|---------|------|---------|-------------|
| `ledger.secrets.LICENSE_KEY` | ledger | string | `""` | Product license key. Required: the ledger refuses to boot when empty. |
| `tracer.secrets.LICENSE_KEY` | tracer | string | `""` | Product license key. Required: the tracer refuses to boot when empty. |

Both fields are stored in the respective service Secrets and base64-encoded by the Helm templates. The application reads them as environment variables at runtime.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.1.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 10.1.0 -n midaz
```
<!-- {% endraw %} -->
