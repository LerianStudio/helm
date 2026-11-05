<!-- {% raw %} -->
# Helm Upgrade from v10.2.1 to v10.2.2

# Topics

- **[Fixes](#fixes)**
  - [1. Caradhras Redis Endpoint Configuration Flexibility](#1-caradhras-redis-endpoint-configuration-flexibility)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Caradhras Redis Endpoint Configuration Flexibility

The chart now allows operators to provide the Caradhras Redis/Valkey session endpoint via ConfigMap (`caradhras.configmap.redisEndpoint`) while still using an external Secret for the license key (`LICENSE_KEY`). Previously, when `caradhras.useExistingSecret` was enabled, the chart always read `redisEndpoint` from the external Secret, and setting `caradhras.configmap.redisEndpoint` as well failed the render.

**What changed:**

The template logic for determining the Redis endpoint source has been updated to check whether `caradhras.configmap.redisEndpoint` is set. When it is, the chart reads the endpoint from the ConfigMap and reads only `LICENSE_KEY` from the external Secret.

| Setting | v10.2.1 | v10.2.2 |
|---------|---------|---------|
| `caradhras.useExistingSecret` behavior | External Secret must contain `redisEndpoint`; `LICENSE_KEY` is read when present | Same, unless `caradhras.configmap.redisEndpoint` is set: then the Secret only needs `LICENSE_KEY` |
| `caradhras.configmap.redisEndpoint` with `useExistingSecret=true` | Render fails: both define `redisEndpoint` | Used; the operator-managed Secret's `redisEndpoint` key is not read |

**Why this matters:**

- **Separation of concerns:** Operators can now store the license key (sensitive) in a Secret while keeping the Redis endpoint (non-sensitive infrastructure config) in the ConfigMap
- **Simplified secret management:** When the Redis endpoint is managed via ConfigMap (e.g., from a central configuration or GitOps workflow), the external Secret only needs to hold the license key
- **Backward compatibility:** Existing configurations where the external Secret contains both keys continue to work unchanged

**Before (v10.2.1):**

When `caradhras.useExistingSecret=true`, the chart always read `redisEndpoint` from the external Secret, and `LICENSE_KEY` when the Secret had it:

```yaml
# values.yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "caradhras-credentials"
```

The Secret `caradhras-credentials` carries `redisEndpoint` and, for Caradhras `2.0.0` and later, `LICENSE_KEY`.

**After (v10.2.2):**

Operators can now choose between two patterns:

#### Option 1: Keep existing behavior (both keys in Secret)

```yaml
# values.yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "caradhras-credentials"
  # Do not set configmap.redisEndpoint
```

The Secret keeps `redisEndpoint` (still read from it) and, for Caradhras `2.0.0` and later, `LICENSE_KEY`.

#### Option 2: Split endpoint (ConfigMap) and license (Secret)

```yaml
# values.yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "caradhras-license"
  configmap:
    redisEndpoint: "redis-service:6379"  # non-sensitive, in ConfigMap
```

The Secret `caradhras-license` needs only `LICENSE_KEY`; its `redisEndpoint` key, if any, is not read.

**Validation and error messages:**

Error messages have been updated to reflect the new flexibility:

| Scenario | v10.2.1 Error Message | v10.2.2 Error Message |
|----------|----------------------|----------------------|
| `useExistingSecret=true` but `existingSecretName` empty | "Set caradhras.existingSecretName to the name of the Secret holding the redisEndpoint and LICENSE_KEY keys." | "Set caradhras.existingSecretName to the name of the Secret holding the LICENSE_KEY key (and redisEndpoint, unless caradhras.configmap.redisEndpoint is set)." |
| Missing Secret name in validation | "Name the Secret holding the redisEndpoint key, or set caradhras.useExistingSecret=false." | "Name the Secret holding LICENSE_KEY (plus redisEndpoint when the ConfigMap has none), or set caradhras.useExistingSecret=false." |

**Operational impact:**

- **No action required:** Existing configurations continue to work without changes
- **Migration opportunity:** If your Redis endpoint is non-sensitive and managed via infrastructure-as-code, you can move it to `caradhras.configmap.redisEndpoint` and simplify your Secret to contain only the license key

**Migration steps (optional):**

If you want to move the Redis endpoint from Secret to ConfigMap:

`caradhras.configmap.redisEndpoint` takes a bare `host:port`. The chart fails the render if the value carries a password field.

1. Add the endpoint to your values file:

```yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "caradhras-license"
  configmap:
    redisEndpoint: "redis-service:6379"  # your endpoint
```

2. Upgrade the chart — the endpoint will now be read from the ConfigMap

3. Update your external Secret to remove the `redisEndpoint` key (keep only `LICENSE_KEY`)

> **Note:** The values.yaml comment for `caradhras.useExistingSecret` has been updated to document this behavior. Review the inline documentation for details on key resolution order.


## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.2.2 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 10.2.2 -n plugin-access-manager
```
<!-- {% endraw %} -->
