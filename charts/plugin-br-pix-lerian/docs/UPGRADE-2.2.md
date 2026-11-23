<!-- {% raw %} -->
# Helm Upgrade from v2.1.0 to v2.2.0

## Topics

- **[Features](#features)**
  - [1. Antifraud Partner Integration](#1-antifraud-partner-integration)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. Antifraud Partner Integration

**Runtime prerequisite:** Both chart 2.1.0 and 2.2.0 default to application image 1.3.0. Those binaries do not consume `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` or `ANTIFRAUD_SECRETS_BACKEND`. This release adds chart wiring, not working partner integration for the default images. Do not rely on these values to restrict routing or select credentials with 1.3.0. Validate the exact application images and their configuration contract separately before enabling a partner flow; this guide does not recommend an image-version jump.

**What changed:**

A new top-level `antifraud` configuration block has been added to `values.yaml`, introducing two settings that control antifraud partner integration for the SPI workloads (`spi` and `spiSystemplane`):

- `antifraud.allowedPrivateHosts` — Comma-separated list of private hosts the antifraud partner route may target
- `antifraud.secretsBackend` — Secrets backend type (`"aws"` or `"vault"`)

These settings are propagated to the `spi` and `spi-systemplane` ConfigMaps as environment variables:

- `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` — Sent to both `spi` and `spiSystemplane` to provide a common chart-level allowlist (component overrides can still make them disagree)
- `ANTIFRAUD_SECRETS_BACKEND` — Sent to `spi` only (the process that reads the credential)

| Setting | v2.1.0 | v2.2.0 |
|---------|--------|--------|
| `antifraud.allowedPrivateHosts` | (not present) | `""` |
| `antifraud.secretsBackend` | (not present) | `""` |

**Why it matters:**

The new values provide configuration inputs for separately validated application images that implement this partner contract. Rendering an allowlist does not prove that the selected binary enforces it; the default 1.3.0 images ignore it.

The chart passes `secretsBackend` through without validating backend support. Credential selection and failure behavior depend on the exact application image; the default 1.3.0 binaries do not consume this variable.

**How to handle it:**

#### If you do not use antifraud partner integration

Both settings default to empty strings and emit no new environment keys. These empty values are not a feature-disable switch: preserve and audit existing environment, Secret and persisted runtime configuration. With identical values and retained image pins, this chart-only upgrade does not change the default application images or pod templates.

#### If you use antifraud partner integration

Only after independently validating application compatibility, merge the intended settings into your complete private values file:

```yaml
antifraud:
  allowedPrivateHosts: "antifraud.internal.example.com,antifraud-backup.internal.example.com"
  secretsBackend: "aws"
```

> **Important:** Coordinate effective values with your deployment owner. Do not overwrite platform-managed configuration or assume that this example is a complete deployment configuration.

> **Warning:** Chart rendering does not validate partner reachability, credentials, application consumption or transaction behavior. Verify those separately before routing traffic.

**After (v2.2.0) values.yaml:**

```yaml
# -- Chart inputs for separately validated compatible partner images.
# A component's own configmap.<KEY> wins over this block.
antifraud:
  # -- ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: comma-separated private hosts the partner
  # route may target with compatible binaries. Sent to spi and spiSystemplane.
  # Default 1.3.0 binaries ignore it. Empty renders nothing.
  allowedPrivateHosts: ""
  # -- ANTIFRAUD_SECRETS_BACKEND: "aws" or "vault". Sent to spi only, the one process
  # that reads the credential with compatible binaries. Empty renders nothing.
  secretsBackend: ""
```

**Template changes:**

The `spi` and `spi-systemplane` ConfigMap templates now include logic to emit the antifraud environment variables when the `antifraud` block is set:

**Before (v2.1.0) spi/configmap.yaml:**

```yaml
{{- range $k := (list
    "ADAPTER_BASE_URL" "APPLICATION_NAME" "COB_BASE_URL" "COB_CLIENT_ID" "COB_CLIENT_SECRET"
    "CRM_BASE_URL" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "CRM_ORGANIZATION_ID" "DATABASE_URL"
    # ...
  )}}
```

**After (v2.2.0) spi/configmap.yaml:**

```yaml
{{- with include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "params" $.Values.antifraud "field" "allowedPrivateHosts" "default" "") }}
ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: {{ . | quote }}
{{- end }}
{{- with include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ANTIFRAUD_SECRETS_BACKEND" "params" $.Values.antifraud "field" "secretsBackend" "default" "") }}
ANTIFRAUD_SECRETS_BACKEND: {{ . | quote }}
{{- end }}
# ...
{{- range $k := (list
    "ADAPTER_BASE_URL" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "ANTIFRAUD_SECRETS_BACKEND" "APPLICATION_NAME" "COB_BASE_URL" "COB_CLIENT_ID" "COB_CLIENT_SECRET"
    "CRM_BASE_URL" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "CRM_ORGANIZATION_ID" "DATABASE_URL"
    # ...
  )}}
```

**Before (v2.1.0) spi-systemplane/configmap.yaml:**

```yaml
{{- range $k := (list
    "ADAPTER_BASE_URL" "APPLICATION_NAME" "COB_BASE_URL" "COB_CLIENT_ID" "COB_CLIENT_SECRET"
    "CRM_BASE_URL" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "DATABASE_URL" "DB_REPLICA_SSL_MODE"
    # ...
  )}}
```

**After (v2.2.0) spi-systemplane/configmap.yaml:**

```yaml
{{- with include "lerian-common.cfgValue" (dict "configmap" $cm "nativeKey" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "params" $.Values.antifraud "field" "allowedPrivateHosts" "default" "") }}
ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: {{ . | quote }}
{{- end }}
# ...
{{- range $k := (list
    "ADAPTER_BASE_URL" "ANTIFRAUD_ALLOWED_PRIVATE_HOSTS" "APPLICATION_NAME" "COB_BASE_URL" "COB_CLIENT_ID" "COB_CLIENT_SECRET"
    "CRM_BASE_URL" "CRM_CLIENT_ID" "CRM_CLIENT_SECRET" "DATABASE_URL" "DB_REPLICA_SSL_MODE"
    # ...
  )}}
```

**Operational impact:**

- The `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` variable is emitted to both `spi` and `spi-systemplane` ConfigMaps when its effective resolved value is non-empty. A component ConfigMap entry takes precedence, including an explicit empty value that suppresses emission.
- The `ANTIFRAUD_SECRETS_BACKEND` variable is emitted to the `spi` ConfigMap when its effective resolved value is non-empty. A component ConfigMap entry takes precedence, including an explicit empty value that suppresses emission.
- A component's own `configmap.<KEY>` always wins over the `antifraud` block. For example, if you set `spi.configmap.ANTIFRAUD_SECRETS_BACKEND`, it will override `antifraud.secretsBackend`.

**Override behavior:**

Prefer the shared block for the allowlist and remove conflicting component overrides. A SPI-only allowlist override can disagree with SPI systemplane admission. If a separately validated deployment needs an override, keep the effective allowlist aligned on both components:

```yaml
spi:
  configmap:
    ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: "custom-host.example.com"
    ANTIFRAUD_SECRETS_BACKEND: "vault"
spiSystemplane:
  configmap:
    ANTIFRAUD_ALLOWED_PRIVATE_HOSTS: "custom-host.example.com"
```

These explicit entries override the shared block. An empty component entry also wins and suppresses the corresponding environment key.

## Configuration Reference

### Antifraud Settings

| Flag | Default | Description |
|------|---------|-------------|
| `antifraud.allowedPrivateHosts` | `""` | Comma-separated list of private hosts the antifraud partner route may target. Chart inputs for `spi` and `spiSystemplane`; runtime consumption requires separately validated compatible binaries. Empty effective value renders nothing. |
| `antifraud.secretsBackend` | `""` | Secrets backend type: `"aws"` or `"vault"`. Sent to `spi` only (the process that reads the credential). Empty effective value renders nothing. Default 1.3.0 binaries ignore this setting. |

### Environment Variables

The following environment variables are added to the `spi` and `spi-systemplane` ConfigMaps:

| Variable | Component | Description |
|----------|-----------|-------------|
| `ANTIFRAUD_ALLOWED_PRIVATE_HOSTS` | `spi`, `spiSystemplane` | Comma-separated list of private hosts the antifraud partner route may target. Emitted when the effective component-or-shared value is non-empty. |
| `ANTIFRAUD_SECRETS_BACKEND` | `spi` | Secrets backend type: `"aws"` or `"vault"`. Emitted when the effective component-or-shared value is non-empty. |

## Upgrade prerequisites and recovery

Privately preserve the current release values, manifests and operator-managed Secret references. Create `values.intended.yaml` containing the complete intended configuration, not only the examples above: retain component enablement, image pins, datastore and storage settings, authentication, networking and Secret references. Keep credentials and rendered manifests out of Git and logs.

Both releases retain appVersion 1.3.0 and the same locked dependencies. With identical configuration and image pins, all 14 component pod templates remain unchanged; setting the shared antifraud values changes the SPI and SPI systemplane ConfigMap checksums and rolls those two workloads, even though 1.3.0 ignores the new variables.

Enabled migration hooks still run before upgrade when a database URL or existing Secret is configured, using the selected component image. Preserve database backups and a rehearsed recovery plan. Successful migration Jobs may be deleted; preserve execution evidence and verify database state through your approved operational process. Helm rollback does not reverse SQL or restore data. Migration hook Secrets can remain after uninstall; handle their lifecycle through your approved secret-management process.

## Preview changes before upgrading

```bash
helm diff upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.2.0 \
  --reset-values -f values.intended.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> Both preview and upgrade must use the same complete intended values. `--reset-values` discards stored overrides omitted from the file. Bundled-store upgrade previews can require the current passwords; supply them privately through your approved values/Secret process, never on the command line or by printing decoded Secrets. Client rendering cannot resolve cluster `lookup`; use an approved server-side preview when applicable. Protect helm-diff output because it can expose sensitive changes.

## Command to upgrade

```bash
helm upgrade <release-name> oci://ghcr.io/lerianstudio/plugin-br-pix-lerian-helm --namespace <namespace> --version 2.2.0 \
  --reset-values -f values.intended.yaml
```
## Validation limits

A successful lint or render is not an application boot, database migration, live upgrade or restore test. Validate the exact selected images, partner contract and recovery process separately. Optional provider-mock image publication and provenance are not established by this guide.
<!-- {% endraw %} -->
