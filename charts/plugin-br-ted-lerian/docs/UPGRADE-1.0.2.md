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

**Impact:** The upgrade will trigger a rolling update of the plugin-br-ted-lerian pods with the new container image. No chart values change is required unless you have explicitly pinned the image tag in your values file.

> **Note:** If you have overridden `plugin-br-ted-lerian.image.tag` in your values file with a specific version, you may want to remove that override to use the chart's default version, or update it to `1.0.0-beta.64` explicitly.

TED fees now come only from your Midaz fee package: the plugin no longer posts its own fee leg and no longer reads `MIDAZ_FEE_REVENUE_ACCOUNT_ALIAS` or the `fee.enabled` and `fee.emission_unavailable_policy` settings. If you charge TED fees, before you upgrade make the package select TED postings by the `tedOperation` transaction metadata. Selecting by transaction metadata (`metadataSelector`) needs Midaz 4.2 or later. The package an outgoing TED applies must charge every fee to the sender: an outgoing TED whose applied package has a deductible fee (`isDeductibleFrom`) is refused.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.0.2 -n plugin-br-ted-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.0.2 -n plugin-br-ted-lerian
```
