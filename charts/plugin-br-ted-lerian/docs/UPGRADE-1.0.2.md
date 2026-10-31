# Helm Upgrade from v1.0.1 to v1.0.2

## Topics

- **[Application Version Update](#application-version-update)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Application Version Update

This patch release updates the application version from `1.0.0-beta.33` to `1.0.0-beta.64`, incorporating 31 beta iterations of the plugin-br-ted-lerian application.

| Setting | v1.0.1 | v1.0.2 |
|---------|--------|--------|
| Chart version | `1.0.1` | `1.0.2` |
| App version | `1.0.0-beta.33` | `1.0.0-beta.64` |
| Image tag | `1.0.0-beta.33` | `1.0.0-beta.64` |

**Before (v1.0.1):**
```yaml
plugin-br-ted-lerian:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-ted-lerian
    pullPolicy: IfNotPresent
    tag: "1.0.0-beta.33"
```

**After (v1.0.2):**
```yaml
plugin-br-ted-lerian:
  image:
    repository: ghcr.io/lerianstudio/plugin-br-ted-lerian
    pullPolicy: IfNotPresent
    tag: "1.0.0-beta.64"
```

**Impact:** This is a standard application version bump. The upgrade will trigger a rolling update of the plugin-br-ted-lerian pods with the new container image. No configuration changes are required unless you have explicitly pinned the image tag in your values file.

> **Note:** If you have overridden `plugin-br-ted-lerian.image.tag` in your values file with a specific version, you may want to remove that override to use the chart's default version, or update it to `1.0.0-beta.64` explicitly.

**No action required** if you are using the default image tag from the chart. The upgrade will automatically pull and deploy the new version.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.0.2 -n plugin-br-ted-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://registry-1.docker.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.0.2 -n plugin-br-ted-lerian
```
