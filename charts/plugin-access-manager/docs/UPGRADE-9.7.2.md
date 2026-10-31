<!-- {% raw %} -->
# Helm Upgrade from v9.7.1 to v9.7.2

# Topics

- **[Fixes](#fixes)**
  - [1. External Secret Validation](#1-external-secret-validation)
  - [2. Auth Service Port Cleanup](#2-auth-service-port-cleanup)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. External Secret Validation

This release adds validation to prevent deployment failures when using external secrets with empty secret names.

**What changed:**

Both the auth and identity deployments now validate that `existingSecretName` is not empty when `useExistingSecret` is enabled. Previously, if you set `useExistingSecret: true` but forgot to provide `existingSecretName`, the deployment would fail with a cryptic error about missing secret references.

**Before (v9.7.1):**

```yaml
# auth deployment - no validation
envFrom:
- secretRef:
    name: {{ if .Values.auth.useExistingSecret }}{{ .Values.auth.existingSecretName }}{{ else }}{{ include "plugin-auth.fullname" . }}{{ end }}
```

**After (v9.7.2):**

```yaml
# auth deployment - with validation
envFrom:
- secretRef:
    name: {{ if .Values.auth.useExistingSecret }}{{ required "\n\nERROR: auth.useExistingSecret is true but auth.existingSecretName is empty.\n   Set auth.existingSecretName to the name of the Secret holding the auth environment (AUTHORIZER_CLIENT_SECRET, LICENSE_KEY, ORGANIZATION_IDS, ...), or set auth.useExistingSecret=false.\n" .Values.auth.existingSecretName }}{{ else }}{{ include "plugin-auth.fullname" . }}{{ end }}
```

**Why this matters:**

- **Fail-fast validation**: The chart now fails during `helm upgrade` with a clear error message instead of allowing a broken deployment
- **Better error messages**: Operators get actionable guidance on what to fix
- **Prevents pod crash loops**: Catches configuration errors before pods are created

**What operators need to do:**

If you're using external secrets, verify your configuration includes both flags:

```yaml
auth:
  useExistingSecret: true
  existingSecretName: my-auth-secret  # Must not be empty

identity:
  useExistingSecret: true
  existingSecretName: my-identity-secret  # Must not be empty
```

> **Important:** If you have `useExistingSecret: true` but `existingSecretName` is empty or not set, the upgrade will fail with a validation error. Either provide the secret name or set `useExistingSecret: false`.

**Error message you'll see if misconfigured:**

```
ERROR: auth.useExistingSecret is true but auth.existingSecretName is empty.
   Set auth.existingSecretName to the name of the Secret holding the auth environment (AUTHORIZER_CLIENT_SECRET, LICENSE_KEY, ORGANIZATION_IDS, ...), or set auth.useExistingSecret=false.
```

**Affected services:**

| Service | Template File | Validation Added |
|---------|--------------|------------------|
| Auth | `templates/auth/deployment.yaml` | ✓ |
| Identity | `templates/identity/deployment.yaml` | ✓ |

### 2. Auth Service Port Cleanup

The auth service definition has been simplified by removing an unused backend port.

**What changed:**

The auth service previously exposed two ports:
- Port 3000 (http) - the main service port
- Port 8000 (http-backend) - an unused port

The `http-backend` port on 8000 has been removed as it was not used by any component.

**Before (v9.7.1):**

```yaml
# auth service
spec:
  ports:
    - port: 3000
      targetPort: http
      protocol: TCP
      name: http
    - port: 8000
      targetPort: http-backend
      protocol: TCP
      name: http-backend
```

**After (v9.7.2):**

```yaml
# auth service
spec:
  ports:
    - port: 3000
      targetPort: http
      protocol: TCP
      name: http
```

**Why this matters:**

- **Cleaner service definition**: Removes unused port configuration
- **No operational impact**: The removed port was not referenced by any ingress, service mesh, or other component
- **Reduced confusion**: Operators won't wonder what the backend port is for

**What operators need to do:**

No action required. This is a cleanup change with no functional impact.

> **Note:** If you have custom monitoring, network policies, or firewall rules that explicitly reference port 8000 on the auth service, you should remove those references. However, this port was not documented or used in any standard configuration.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.7.2 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.7.2 -n plugin-access-manager
```
<!-- {% endraw %} -->
