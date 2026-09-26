# Helm Upgrade from v9.5.5 to v9.5.6

# Topics

- **[Fixes](#fixes)**
  - [1. ConfigMap Change Detection](#1-configmap-change-detection)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. ConfigMap Change Detection

This release adds checksum annotations for ConfigMaps to deployment templates, ensuring pods are automatically restarted when ConfigMap values change.

**What changed:**

The following deployments now include ConfigMap checksum annotations in their pod template metadata:

| Service | New Annotation |
|---------|----------------|
| Auth | `checksum/config` |
| Caradhras | `checksum/config`, `checksum/auth-config` |
| Identity | `checksum/config` |

**Why this matters:**

Previously, when you updated ConfigMap values in your `values.yaml` and ran `helm upgrade`, the deployments would not automatically restart their pods. This meant configuration changes would not take effect until pods were manually restarted or naturally recycled.

With this fix, any change to a service's ConfigMap will trigger an automatic rolling restart of its pods during the next `helm upgrade`.

**Before (v9.5.5):**

```yaml
# auth/deployment.yaml
spec:
  template:
    metadata:
      annotations:
        checksum/secret: {{ include (print $.Template.BasePath "/auth/secrets.yaml") . | sha256sum }}
      labels:
        {{- include "plugin-auth.labels" (dict "context" . "name" .Values.auth.name ) | nindent 8 }}
```

**After (v9.5.6):**

```yaml
# auth/deployment.yaml
spec:
  template:
    metadata:
      annotations:
        checksum/secret: {{ include (print $.Template.BasePath "/auth/secrets.yaml") . | sha256sum }}
        checksum/config: {{ include (print $.Template.BasePath "/auth/configmap.yaml") . | sha256sum }}
      labels:
        {{- include "plugin-auth.labels" (dict "context" . "name" .Values.auth.name ) | nindent 8 }}
```

**Operational impact:**

- **No action required:** This change is automatic and backward compatible
- **Behavior change:** After upgrading to v9.5.6, any future ConfigMap changes will trigger pod restarts
- **During upgrade:** Pods will restart as part of the normal upgrade process due to the new annotation being added

**Example scenario:**

If you modify Redis configuration in your `values.yaml`:

```yaml
auth:
  configmap:
    REDIS_HOST: new-redis-host.example.com
    REDIS_PORT: "6380"
```

Then run:

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.6 -n plugin-access-manager -f values.yaml
```

The auth pods will automatically restart to pick up the new Redis configuration, whereas in v9.5.5 they would have continued running with the old configuration.

> **Note:** The caradhras service now tracks both its own ConfigMap and the auth ConfigMap, since it depends on auth service configuration. Changes to either ConfigMap will trigger a caradhras pod restart.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.6 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.6 -n plugin-access-manager
```
