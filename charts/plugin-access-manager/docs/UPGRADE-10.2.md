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

The chart now supports injecting a Caradhras license key (`LICENSE_KEY`) as an environment variable into the Caradhras deployment. This is required by Caradhras `2.0.0` and later, which carry a license gate and refuse to boot without a valid license key issued for the `caradhras` product. The chart default Caradhras image stays `1.8.6`, which ignores `LICENSE_KEY`.

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

The chart now injects the `LICENSE_KEY` environment variable into the Caradhras deployment, by `secretKeyRef` with `optional: true`, when `caradhras.secrets.LICENSE_KEY` is set or `caradhras.useExistingSecret` is true. The chart-managed Secret now renders when either `redisEndpoint` or `LICENSE_KEY` is set.

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
    LICENSE_KEY: "your-caradhras-license-key-here"
```

**Method B: External Secret (operator-managed)**

If you manage the Caradhras Secret yourself (`caradhras.useExistingSecret: true`), add the `LICENSE_KEY` key to your existing Secret. In this release that Secret must also keep its `redisEndpoint` key.

Then ensure your `values.yaml` references the Secret:

```yaml
caradhras:
  useExistingSecret: true
  existingSecretName: "my-caradhras-secret"
```

> **Important:** In v10.2.0, `caradhras.useExistingSecret: true` together with `caradhras.configmap.redisEndpoint` fails the render ("both define redisEndpoint"). To take only `LICENSE_KEY` from an existing Secret while the endpoint stays in the ConfigMap, upgrade to v10.2.2 or later.

> **Important:** If you are using `caradhras.useExistingSecret: true`, you must add the `LICENSE_KEY` key to your existing Secret **before** upgrading to a Caradhras image version that requires it. If the Secret lacks the key and you upgrade to a licensed image, the Caradhras pods will fail to start with a license validation error.

> **Note:** The license key is product-specific. The `caradhras` license key is different from the `auth` or `identity` license keys. Ensure you request and use the correct key for the Caradhras component.

**Operational impact:**

1. **Secret updates**: If you provide `caradhras.secrets.LICENSE_KEY` inline, the chart will update the `<release>-caradhras` Secret to include the new key.

2. **Rolling restart**: An inline `caradhras.secrets.LICENSE_KEY` changes the `checksum/secret` annotation, so the upgrade rolls the Caradhras pods. With `caradhras.useExistingSecret`, that annotation does not change when you add the key to your own Secret, so restart the Caradhras deployment yourself:

```bash
kubectl rollout restart deployment/<release>-caradhras -n plugin-access-manager
```

3. **Migration path**: You can upgrade the chart to v10.2.0 first (without changing the Caradhras image version), add the license key to the Secret, and then upgrade the Caradhras image version in a subsequent Helm upgrade.

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
