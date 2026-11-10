<!-- {% raw %} -->
# Helm Upgrade from v4.1.0 to v4.2.0

## Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. PostgreSQL TLS Security Warning in NOTES.txt](#1-postgresql-tls-security-warning-in-notestxt)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a minor release that adds a security warning to the Helm chart's post-install/upgrade notes when external PostgreSQL connections are configured without TLS encryption. The application version remains `1.11.0` and no values are removed or renamed, so existing custom values continue to work without changes.

The expected upgrade path is an in-place Helm upgrade with no required configuration changes. However, operators should review the new security warning and consider enabling TLS for external PostgreSQL connections if not already configured.

| Component | v4.1.0 | v4.2.0 |
|-----------|--------|--------|
| Chart version | `4.1.0` | `4.2.0` |
| App version | `1.11.0` | `1.11.0` |
| Components | 5 (pix, inbound, outbound, reconciliation, schedule) | 5 (pix, inbound, outbound, reconciliation, schedule) |

## Features

### 1. PostgreSQL TLS Security Warning in NOTES.txt

The chart now displays a security warning in the post-install/upgrade notes when external PostgreSQL connections are configured without TLS encryption.

**What changed:**

The `templates/NOTES.txt` file now includes logic that inspects the `DB_SSL_MODE` configuration for all four database-connected components (`pix`, `inbound`, `outbound`, `reconciliation`) and displays a warning if any component is configured to connect to an external PostgreSQL instance without requiring TLS.

**After (v4.2.0):**

```yaml
{{- /* Read DB_SSL_MODE from each rendered ConfigMap; only require and stricter encrypt. */}}
{{- $plaintext := list }}
{{- if ne (include "plugin-br-pix-indirect-btg.postgresInternal" .) "true" }}
{{- range $c := list "pix" "inbound" "outbound" "reconciliation" }}
{{- $cm := include (printf "%s/%s/configmap.yaml" $.Template.BasePath $c) $ | fromYaml }}
{{- if not (has $cm.data.DB_SSL_MODE (list "require" "verify-ca" "verify-full")) }}
{{- $plaintext = append $plaintext $c }}
{{- end }}
{{- end }}
{{- end }}
{{- if $plaintext }}

---

⚠️  WARNING: external PostgreSQL connection is NOT encrypted

  The components below connect to PostgreSQL without TLS, so the database
  credentials and Pix data cross the network in plaintext. To require TLS, set:
{{- range $plaintext }}
    {{ . }}.configmap.DB_SSL_MODE: "require"
    {{ . }}.configmap.ALLOW_INSECURE_TLS: "false"
{{- end }}

  ALLOW_INSECURE_TLS "false" makes the component refuse to start on any
  plaintext datastore, MongoDB and Valkey included.
{{- end }}
```

**Why it matters:**

When PostgreSQL connections are not encrypted with TLS, sensitive data including database credentials, Pix transaction details, and customer information are transmitted in plaintext across the network. This creates a significant security risk, especially in production environments where network traffic may traverse untrusted networks or be subject to regulatory compliance requirements.

The warning helps operators identify insecure configurations during deployment and provides clear remediation steps.

**Operational impact:**

This change is **non-breaking** and **informational only**. The warning appears in the Helm output after installation or upgrade when the following conditions are met:

1. External PostgreSQL is configured (internal PostgreSQL subchart is not enabled)
2. One or more components have `DB_SSL_MODE` set to a value other than `require`, `verify-ca`, or `verify-full`

**When the warning appears:**

The warning will be displayed if any component's `DB_SSL_MODE` is set to:

- `disable` (TLS disabled entirely)
- `allow` (TLS optional, prefers plaintext)
- `prefer` (TLS optional, prefers encrypted but falls back to plaintext)
- Empty or unset (defaults to `prefer` in most PostgreSQL drivers)

**When the warning does NOT appear:**

The warning is suppressed when:

- Internal PostgreSQL is enabled (`postgresInternal` is `true`)
- All components have `DB_SSL_MODE` set to `require`, `verify-ca`, or `verify-full`

**PostgreSQL SSL modes explained:**

| Mode | Encryption | Certificate Validation | Security Level |
|------|------------|----------------------|----------------|
| `disable` | No | No | **Insecure** - plaintext only |
| `allow` | Optional (prefers plaintext) | No | **Insecure** - may use plaintext |
| `prefer` | Optional (prefers encrypted) | No | **Insecure** - may fall back to plaintext |
| `require` | Yes | No | **Secure** - encrypted, no certificate check |
| `verify-ca` | Yes | Yes (CA only) | **More secure** - encrypted with CA validation |
| `verify-full` | Yes | Yes (CA + hostname) | **Most secure** - encrypted with full validation |

**Example warning output:**

```
---

⚠️  WARNING: external PostgreSQL connection is NOT encrypted

  The components below connect to PostgreSQL without TLS, so the database
  credentials and Pix data cross the network in plaintext. To require TLS, set:
    pix.configmap.DB_SSL_MODE: "require"
    pix.configmap.ALLOW_INSECURE_TLS: "false"
    inbound.configmap.DB_SSL_MODE: "require"
    inbound.configmap.ALLOW_INSECURE_TLS: "false"

  ALLOW_INSECURE_TLS "false" makes the component refuse to start on any
  plaintext datastore, MongoDB and Valkey included.
```

**Recommended configuration for production:**

If you are using an external PostgreSQL instance, configure TLS for all components:

```yaml
pix:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

inbound:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

outbound:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

reconciliation:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"
```

> **Important:** Setting `ALLOW_INSECURE_TLS: "false"` enforces TLS not only for PostgreSQL but also for MongoDB and Valkey (Redis) connections. Ensure all your datastores support TLS before enabling this setting, or the components will fail to start.

**Certificate configuration:**

If your PostgreSQL instance uses a self-signed certificate or a certificate signed by a private CA, you may need to provide the CA certificate to the components. Consult your PostgreSQL documentation and the application's TLS configuration guide for certificate setup instructions.

For `verify-ca` or `verify-full` modes, you will typically need to:

1. Create a Kubernetes Secret containing the CA certificate
2. Mount the secret into the component pods
3. Configure the `DB_SSL_ROOT_CERT` environment variable to point to the certificate file path

**Development and testing environments:**

For non-production environments where network security is not a concern, you may choose to suppress the warning by explicitly setting `DB_SSL_MODE` to `disable`:

```yaml
pix:
  configmap:
    DB_SSL_MODE: "disable"
```

> **Warning:** Never use `DB_SSL_MODE: "disable"` in production environments. This configuration transmits all database traffic in plaintext and should only be used in isolated development or testing environments.

## Migration Steps

This upgrade requires no configuration changes. The new security warning is informational and does not affect runtime behavior.

**Recommended upgrade process:**

1. Review your current PostgreSQL connection configuration for all components:

```bash
helm get values plugin-br-pix-indirect-btg -n plugin-br-pix-indirect-btg
```

2. Check if you are using external PostgreSQL (internal PostgreSQL subchart disabled) and whether TLS is configured:

```bash
helm get values plugin-br-pix-indirect-btg -n plugin-br-pix-indirect-btg | grep -E "(postgresInternal|DB_SSL_MODE)"
```

3. Preview the upgrade to see if the security warning will appear:

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.2.0 -n plugin-br-pix-indirect-btg
```

4. Run the upgrade command:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.2.0 -n plugin-br-pix-indirect-btg
```

5. Review the post-upgrade notes for the security warning. If the warning appears, plan to enable TLS for your PostgreSQL connections in a future maintenance window.

6. Verify all pods are running and healthy after the upgrade:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg
```

**If the security warning appears:**

The warning indicates that one or more components are connecting to PostgreSQL without TLS encryption. To remediate:

1. Verify your PostgreSQL instance supports TLS connections. Consult your PostgreSQL provider's documentation for TLS configuration.

2. Update your Helm values to require TLS for all components:

```yaml
pix:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

inbound:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

outbound:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"

reconciliation:
  configmap:
    DB_SSL_MODE: "require"
    ALLOW_INSECURE_TLS: "false"
```

3. If your PostgreSQL instance uses a custom CA certificate, configure certificate validation. See your application's TLS configuration documentation for details.

4. Run another Helm upgrade to apply the TLS configuration:

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.2.0 -n plugin-br-pix-indirect-btg -f values.yaml
```

5. Verify the components start successfully with TLS enabled:

```bash
kubectl get pods -n plugin-br-pix-indirect-btg
kubectl logs -n plugin-br-pix-indirect-btg -l app.kubernetes.io/component=pix --tail=50
```

> **Note:** Enabling `ALLOW_INSECURE_TLS: "false"` will cause components to fail startup if any datastore connection (PostgreSQL, MongoDB, or Valkey) does not support TLS. Test this configuration in a non-production environment first.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.2.0 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 4.2.0 -n plugin-br-pix-indirect-btg
```
<!-- {% endraw %} -->
