<!-- {% raw %} -->
# Helm Upgrade from v10.1.4 to v10.2.0

# Topics

- **[Features](#features)**
  - [1. Caradhras License Key Support](#1-caradhras-license-key-support)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Features

### 1. Caradhras License Key Support

**What changed:**

The chart now supports injecting a Caradhras license key (`LICENSE_KEY`) as an environment variable into the Caradhras deployment. This is required by newer Caradhras images that carry a license gate and refuse to boot without a valid license key issued for the `caradhras` product.

| Setting | v10.1.4 | v10.2.0 |
|---------|---------|---------|
| `caradhras.secrets.LICENSE_KEY` | Not present | Empty string (optional) |
| Secret keys managed by chart | `redisEndpoint` | `redisEndpoint`, `LICENSE_KEY` |
| Secret keys read from existing secret | `redisEndpoint` | `redisEndpoint`, `LICENSE_KEY` |

**values.yaml changes:**

**Before (v10.1.4):**

```yaml
caradhras:
  secrets:
    # -- Beego session store connection string, host:port,poolsize,password,dbnum.
    # Held here and injected with secretKeyRef because the third field is a
    # password; the ConfigMap channel is refused for a value that carries one.
    # Mutually exclusive with caradhras.configmap.redisEndpoint. If both are
    # set, the ConfigMap value is ignored and the Secret value (this one)
    # reaches a ConfigMap. Mutually exclusive with
    # caradhras.configmap.redisEndpoint.
    redisEndpoint: ""
  # -- Set true to manage the caradhras Secret yourself: the chart creates none
  # and reads key `redisEndpoint` from existingSecretName instead.
  useExistingSecret: false
  existingSecretName: ""
```

**After (v10.2.0):**

```yaml
caradhras:
  secrets:
    # -- Beego session store connection string, host:port,poolsize,password,dbnum.
    # Held here and injected with secretKeyRef because the third field is a
    # password; the ConfigMap channel is refused for a value that carries one.
    # Mutually exclusive with caradhras.configmap.redisEndpoint. If both are
    # set, the ConfigMap value is ignored and the Secret value (this one)
    # reaches a ConfigMap. Mutually exclusive with
    # caradhras.configmap.redisEndpoint.
    redisEndpoint: ""
    # -- Caradhras license key, injected as env LICENSE_KEY by secretKeyRef.
    # Required by images that carry the license gate (they refuse to boot
    # without it). Issued for product `caradhras`; not the auth/identity key.
    LICENSE_KEY: ""
  # -- Set true to manage the caradhras Secret yourself: the chart creates none
  # and reads keys `redisEndpoint` and `LICENSE_KEY` from existingSecretName.
  useExistingSecret: false
  existingSecretName: ""
```

**Template changes:**

The chart now injects the `LICENSE_KEY` environment variable into the Caradhras deployment when the license key is provided, and the Secret creation logic has been updated to include the license key.

**Before (v10.1.4):**

```yaml
# templates/_helpers.tpl
{{- define "plugin-caradhras.sessionSecretName" -}}
{{- if .Values.caradhras.useExistingSecret -}}
{{- required "\n\nERROR: caradhras.useExistingSecret is true but caradhras.existingSecretName is empty.\n   Set caradhras.existingSecretName to the name of the Secret holding the redisEndpoint key.\n" .Values.caradhras.existingSecretName -}}
{{- else -}}
{{- include "plugin-caradhras.fullname" . -}}
{{- end -}}
{{- end }}
```

```yaml
# templates/caradhras/deployment.yaml
env:
  - name: redisEndpoint
    valueFrom:
      secretKeyRef:
        name: {{ include "plugin-caradhras.sessionSecretName" . }}
        key: redisEndpoint
```

```yaml
# templates/caradhras/secrets.yaml
{{- $secrets := .Values.caradhras.secrets | default dict -}}
{{- $redisEndpoint := $secrets.redisEndpoint | default "" | toString -}}
{{- if and (not .Values.caradhras.useExistingSecret) $redisEndpoint }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "plugin-caradhras.fullname" . }}
  labels:
    {{- include "plugin-caradhras.labels" (dict "context" . "name" .Values.caradhras.name ) | nindent 4 }}
type: Opaque
data:
  redisEndpoint: {{ $redisEndpoint | b64enc | quote }}
{{- end }}
```

**After (v10.2.0):**

```yaml
# templates/_helpers.tpl
{{- define "plugin-caradhras.secretName" -}}
{{- if .Values.caradhras.useExistingSecret -}}
{{- required "\n\nERROR: caradhras.useExistingSecret is true but caradhras.existingSecretName is empty.\n   Set caradhras.existingSecretName to the name of the Secret holding the redisEndpoint and LICENSE_KEY keys.\n" .Values.caradhras.existingSecretName -}}
{{- else -}}
{{- include "plugin-caradhras.fullname" . -}}
{{- end -}}
{{- end }}
```

```yaml
# templates/caradhras/deployment.yaml
env:
  - name: redisEndpoint
    valueFrom:
      secretKeyRef:
        name: {{ include "plugin-caradhras.secretName" . }}
        key: redisEndpoint
  {{- if or (.Values.caradhras.secrets | default dict).LICENSE_KEY .Values.caradhras.useExistingSecret }}
  # Caradhras refuses to boot without its own license key (product
  # `caradhras`, not the auth/identity key). optional: a Secret lacking
  # the key renders no env, so older images keep booting on upgrade.
  - name: LICENSE_KEY
    valueFrom:
      secretKeyRef:
        name: {{ include "plugin-caradhras.secretName" . }}
        key: LICENSE_KEY
        optional: true
  {{- end }}
```

```yaml
# templates/caradhras/secrets.yaml
{{- $secrets := .Values.caradhras.secrets | default dict -}}
{{- $redisEndpoint := $secrets.redisEndpoint | default "" | toString -}}
{{- $licenseKey := $secrets.LICENSE_KEY | default "" | toString -}}
{{- if and (not .Values.caradhras.useExistingSecret) (or $redisEndpoint $licenseKey) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "plugin-caradhras.fullname" . }}
  labels:
    {{- include "plugin-caradhras.labels" (dict "context" . "name" .Values.caradhras.name ) | nindent 4 }}
type: Opaque
data:
  {{- if $redisEndpoint }}
  redisEndpoint: {{ $redisEndpoint | b64enc | quote }}
  {{- end }}
  {{- if $licenseKey }}
  LICENSE_KEY: {{ $licenseKey | b64enc | quote }}
  {{- end }}
{{- end }}
```

**Why this matters:**

Newer versions of the Caradhras image include a license gate that prevents the application from starting without a valid `LICENSE_KEY` environment variable. This license key is issued specifically for the `caradhras` product and is distinct from the auth/identity license keys used by other components.

The chart now provides two mechanisms for supplying the license key:

1. **Inline via `caradhras.secrets.LICENSE_KEY`**: The chart creates a Secret containing the license key and injects it into the deployment
2. **External Secret via `caradhras.useExistingSecret`**: Operators manage their own Secret containing both `redisEndpoint` and `LICENSE_KEY` keys

**Backward compatibility:**

The license key injection is **optional** and backward-compatible:

- The `LICENSE_KEY` environment variable is only injected if `caradhras.secrets.LICENSE_KEY` is set or `caradhras.useExistingSecret` is true
- The Secret key reference uses `optional: true`, so if the Secret exists but lacks the `LICENSE_KEY` key, the pod will still start (allowing older Caradhras images without the license gate to continue working)
- If you are running an older Caradhras image that does not require a license key, no action is required — the upgrade will not break your deployment

**What operators need to do:**

#### Option 1: Running older Caradhras images (no license gate)

No action required. The upgrade is backward-compatible and your existing deployment will continue to work.

#### Option 2: Upgrading to newer Caradhras images (with license gate)

If you plan to upgrade to a Caradhras image version that requires a license key, you must provide the license key before or during the upgrade.

**Step 1: Obtain a Caradhras license key**

Contact your Lerian Studio support representative to obtain a license key issued for the `caradhras` product. This is a separate key from the auth/identity license keys.

**Step 2: Choose a configuration method**

**Method A: Inline license key (chart-managed Secret)**

Set the license key in your `values.yaml`:

```yaml
caradhras:
  secrets:
    redisEndpoint: "redis.example.com:6379,100,mypassword,0"
    LICENSE_KEY: "your-caradhras-license-key-here"
```

Or pass it via `--set` during upgrade:

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager \
  --version 10.2.0 \
  --set caradhras.secrets.LICENSE_KEY="your-caradhras-license-key-here" \
  -n plugin-access-manager
```

**Method B: External Secret (operator-managed)**

If you manage the Caradhras Secret yourself (`caradhras.useExistingSecret: true`), add the `LICENSE_KEY` key to your existing Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-caradhras-secret
  namespace: plugin-access-manager
type: Opaque
stringData:
  redisEndpoint: "redis.example.com:6379,100,mypassword,0"
  LICENSE_KEY: "your-caradhras-license-key-here"
```

Then ensure your `values.yaml` references the Secret:

```yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "my-caradhras-secret"
```

> **Important:** If you are using `caradhras.useExistingSecret: true`, you must add the `LICENSE_KEY` key to your existing Secret **before** upgrading to a Caradhras image version that requires it. If the Secret lacks the key and you upgrade to a licensed image, the Caradhras pods will fail to start with a license validation error.

> **Note:** The license key is product-specific. The `caradhras` license key is different from the `auth` or `identity` license keys. Ensure you request and use the correct key for the Caradhras component.

**Operational impact:**

1. **Secret updates**: If you provide `caradhras.secrets.LICENSE_KEY` inline, the chart will update the `<release>-caradhras` Secret to include the new key. Kubernetes will automatically mount the updated Secret into running pods, but the Caradhras application will not reload the environment variable until the pod restarts.

2. **Rolling restart**: After adding the license key to the Secret, you may need to trigger a rolling restart of the Caradhras deployment to pick up the new environment variable:

```bash
kubectl rollout restart deployment/<release>-caradhras -n plugin-access-manager
```

3. **Image compatibility**: The `optional: true` flag on the Secret key reference ensures that:
   - Older Caradhras images (without license gate) continue to work even if the Secret contains a `LICENSE_KEY` key
   - Newer Caradhras images (with license gate) will fail to start if the `LICENSE_KEY` environment variable is missing or invalid

4. **Migration path**: You can upgrade the chart to v10.2.0 first (without changing the Caradhras image version), add the license key to the Secret, verify it is mounted correctly, and then upgrade the Caradhras image version in a subsequent Helm upgrade.

> **Warning:** If you upgrade to a Caradhras image version that requires a license key without providing `caradhras.secrets.LICENSE_KEY` or adding the key to your existing Secret, the Caradhras pods will enter `CrashLoopBackOff` with a license validation error. Check the pod logs to confirm:
>
> ```bash
> kubectl logs deployment/<release>-caradhras -n plugin-access-manager
> ```

# Configuration Reference

The following new configuration fields have been added in v10.2.0:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `caradhras.secrets.LICENSE_KEY` | string | `""` | Caradhras license key, injected as environment variable `LICENSE_KEY`. Required by Caradhras images with license gate. Issued for product `caradhras` (not auth/identity). |

**Environment variables:**

The following environment variable is now injected into the Caradhras deployment when configured:

| Variable | Source | Description |
|----------|--------|-------------|
| `LICENSE_KEY` | `caradhras.secrets.LICENSE_KEY` or external Secret | Caradhras product license key. Required by images with license gate. Injected via `secretKeyRef` with `optional: true`. |

**Secret schema changes:**

The chart-managed Secret (`<release>-caradhras`) now supports two keys:

| Key | v10.1.4 | v10.2.0 | Description |
|-----|---------|---------|-------------|
| `redisEndpoint` | Required | Optional | Beego session store connection string |
| `LICENSE_KEY` | Not present | Optional | Caradhras license key |

If you use `caradhras.useExistingSecret: true`, your external Secret should include both keys (though `LICENSE_KEY` is only required for licensed images).

**Helper template changes:**

| Template | v10.1.4 | v10.2.0 | Change |
|----------|---------|---------|--------|
| `plugin-caradhras.sessionSecretName` | Returned Secret name | Removed | Renamed to `plugin-caradhras.secretName` |
| `plugin-caradhras.secretName` | Not present | Returns Secret name | New name reflects that Secret now holds multiple keys, not just session config |

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.2.0 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.2.0 -n plugin-access-manager
```
<!-- {% endraw %} -->
