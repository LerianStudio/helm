<!-- {% raw %} -->
# Helm Upgrade from v1.0.2 to v1.1.0

## Topics

- **[Features](#features)**
  - [1. Optional LICENSE_KEY Secret](#1-optional-license_key-secret)
- **[Configuration Reference](#configuration-reference)**
  - [Secrets Configuration](#secrets-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Features

### 1. Optional LICENSE_KEY Secret

The chart now supports an optional `LICENSE_KEY` secret field for product licensing. This field is conditionally rendered: it only appears in the Secret resource when explicitly set to a non-empty value.

| Feature | Default | Description |
|---------|---------|-------------|
| `plugin-br-ted-lerian.secrets.LICENSE_KEY` | `""` | Product license key (optional) |

**New secret field:**

```yaml
plugin-br-ted-lerian:
  secrets:
    LICENSE_KEY: ""
```

**Behavior:**

- When `LICENSE_KEY` is empty (`""`), the key is **not rendered** in the Secret resource
- When `LICENSE_KEY` is set to a non-empty value, it is included in the Secret and exposed as an environment variable to the application

**Template logic change:**

**Before (v1.0.2):**
```yaml
stringData:
  {{- range $key, $value := (index .Values "plugin-br-ted-lerian").secrets }}
  {{- if not (or (and $pgInternal (eq $key "POSTGRES_PASSWORD")) (and $vkInternal (eq $key "REDIS_PASSWORD"))) }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- end }}
```

**After (v1.1.0):**
```yaml
stringData:
  {{- range $key, $value := (index .Values "plugin-br-ted-lerian").secrets }}
  {{- if not (or (and $pgInternal (eq $key "POSTGRES_PASSWORD")) (and $vkInternal (eq $key "REDIS_PASSWORD")) (and (eq $key "LICENSE_KEY") (not $value))) }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- end }}
```

**Impact:** The template now excludes `LICENSE_KEY` from the Secret when its value is empty, preventing the creation of an empty environment variable. This is consistent with the existing behavior for `POSTGRES_PASSWORD` and `REDIS_PASSWORD` when using bundled subcharts.

**New environment variable (when set):**

- `LICENSE_KEY`: Product license key for commercial features

> **Note:** This field is entirely optional. If you are not using licensed features, you do not need to set this value. The application will function normally without it.

---

## Configuration Reference

### Secrets Configuration

```yaml
plugin-br-ted-lerian:
  secrets:
    POSTGRES_PASSWORD: ""
    REDIS_PASSWORD: ""
    MULTI_TENANT_SERVICE_API_KEY: ""
    MULTI_TENANT_REDIS_PASSWORD: ""
    LICENSE_KEY: ""  # New in v1.1.0
  useExistingSecret: false
  existingSecretName: ""
```

| Field | Default | Description |
|-------|---------|-------------|
| `LICENSE_KEY` | `""` | Product license key (optional, only rendered when non-empty) |

---

## Migration Steps

This is a non-breaking change. No action is required to upgrade from v1.0.2 to v1.1.0.

**Optional: Add license key**

If you have a product license key and want to enable licensed features:

1. Add the `LICENSE_KEY` to your values file:

```yaml
plugin-br-ted-lerian:
  secrets:
    LICENSE_KEY: "your-license-key-here"
```

2. Alternatively, set it via `--set` during upgrade:

```bash
helm upgrade plugin-br-ted-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-ted-lerian-helm \
  --version 1.1.0 \
  -n plugin-br-ted-lerian \
  --set plugin-br-ted-lerian.secrets.LICENSE_KEY="your-license-key-here"
```

3. If using an existing Secret (`useExistingSecret: true`), add the `LICENSE_KEY` key to your external Secret:

```bash
kubectl create secret generic plugin-br-ted-lerian-secrets \
  --from-literal=POSTGRES_PASSWORD="..." \
  --from-literal=REDIS_PASSWORD="..." \
  --from-literal=LICENSE_KEY="your-license-key-here" \
  -n plugin-br-ted-lerian \
  --dry-run=client -o yaml | kubectl apply -f -
```

> **Note:** If you do not set `LICENSE_KEY`, the upgrade will proceed without any changes to your Secret resource. The field will simply be omitted.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.0 -n plugin-br-ted-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.0 -n plugin-br-ted-lerian
```
<!-- {% endraw %} -->
