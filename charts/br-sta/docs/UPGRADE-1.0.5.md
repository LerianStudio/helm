# Helm Upgrade from v1.0.4 to v1.0.5

This is a patch release that clarifies documentation around the mock STA component's image access requirements. No functional changes are introduced, but operators using or planning to use the mock STA feature should review the updated image pull secret requirements.

## Topics

- **[Documentation Updates](#documentation-updates)**
  - [Mock STA Image Access Clarification](#mock-sta-image-access-clarification)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Documentation Updates

### Mock STA Image Access Clarification

The documentation for `imagePullSecrets` and `mockSta` has been updated to clarify that the mock STA image is **not publicly available** on GHCR and requires authentication.

| Setting | v1.0.4 | v1.0.5 |
|---------|--------|--------|
| `imagePullSecrets` description | "The images are public on GHCR, so none is needed by default" | "The app images are public on GHCR, so none is needed by default; set it for a private mirror or registry, or for the mock STA image (not public)" |
| `mockSta` image access | "The image is public on GHCR" | "The image is not public: ask Lerian for read access and name a ghcr.io pull secret in imagePullSecrets" |

**Before (v1.0.4):**

```yaml
# -- Pull secrets for the manager, worker, migrations Job and mock STA. The images are
# public on GHCR, so none is needed by default; set it only for a private mirror or
# registry, e.g. [{name: my-registry-credential}]. Per-component lists override it.
imagePullSecrets: []
```

**After (v1.0.5):**

```yaml
# -- Pull secrets for the manager, worker, migrations Job and mock STA. The app images are
# public on GHCR, so none is needed by default; set it for a private mirror or
# registry, or for the mock STA image (not public), e.g. [{name: my-registry-credential}]. Per-component lists override it.
imagePullSecrets: []
```

#### What Changed

The documentation now explicitly states that:

1. The **application images** (manager, worker, migrations) remain public on GHCR
2. The **mock STA image** is **not public** and requires authentication
3. Operators must request read access from Lerian Studio and configure a pull secret

#### Impact on Operators

**If you are NOT using mock STA (`mockSta.enabled: false`):**

No action required. The upgrade will proceed without changes.

**If you ARE using mock STA (`mockSta.enabled: true`):**

You must ensure a valid GHCR pull secret is configured. If you have been successfully pulling the mock STA image in v1.0.4, your existing configuration remains valid. If you encounter image pull errors after upgrading, follow the steps below.

#### Migration Steps for Mock STA Users

If you need to configure authentication for the mock STA image:

1. **Request access** from Lerian to the mock STA image on GHCR.

2. **Create an image pull secret** for `ghcr.io` in the release namespace (here `ghcr-pull-secret`), following [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/).

3. **Configure the pull secret** in your `values.yaml`:

```yaml
imagePullSecrets:
  - name: ghcr-pull-secret

mockSta:
  enabled: true
```

Alternatively, use the component-specific override:

```yaml
mockSta:
  enabled: true
  imagePullSecrets:
    - name: ghcr-pull-secret
```

> **Note:** The `mockSta.imagePullSecrets` setting, when non-empty, overrides the top-level `imagePullSecrets` list for the mock STA deployment only.

> **Important:** The mock STA component is intended for development and testing environments only. It should not be enabled in production deployments.

## Preview changes before upgrading

```bash
helm diff upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm --version 1.0.5 -n br-sta
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sta oci://ghcr.io/lerianstudio/br-sta-helm --version 1.0.5 -n br-sta
```
