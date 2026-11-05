<!-- {% raw %} -->
# Helm Upgrade from v11.0.0 to v11.0.1

# Topics

- **[Fixes](#fixes)**
  - [1. Caradhras Image Tag Validation for Digest-Based Tags](#1-caradhras-image-tag-validation-for-digest-based-tags)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Caradhras Image Tag Validation for Digest-Based Tags

The chart's built-in admin password validation now correctly handles Caradhras images referenced by digest (e.g., `sha256:abc123...`) instead of failing with a false negative.

**What changed:**

The `plugin-caradhras.builtInAdminPasswordEnv` helper template now strips digest suffixes (`@sha256:...`) before performing semver validation. This allows operators to use digest-pinned images while still enforcing the minimum Caradhras version requirement for the `builtInAdminPassword` feature.

| Component | Change | v11.0.0 | v11.0.1 |
|-----------|--------|---------|---------|
| `_helpers.tpl` | Digest handling | Digest tags caused validation failure | Digest suffix stripped before validation |
| `_helpers.tpl` | Regex pattern | `^v?[0-9]+\\.[0-9]+\\.[0-9]+` | `^v?[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$` |
| `_helpers.tpl` | Error message | "a digest or latest cannot be checked" | "a bare digest or latest cannot be checked" |

**Why this matters:**

- **Digest-based deployments:** Operators who pin Caradhras images using content-addressable digests (e.g., `1.9.0@sha256:abc123...`) can now use `caradhras.builtInAdminPassword.enabled: true` without the chart incorrectly rejecting the tag
- **Prerelease tag support:** The updated regex now correctly recognizes semver prerelease tags (e.g., `1.9.0-beta.25`, `1.10.0-rc.1`) that include hyphens and additional identifiers
- **Security best practice:** Digest pinning is a recommended practice for supply chain security; this fix removes an artificial barrier to using it

**Before (v11.0.0):**

```yaml
{{- define "plugin-caradhras.builtInAdminPasswordEnv" -}}
{{- $bp := .Values.caradhras.builtInAdminPassword | default dict -}}
{{- $tag := include "caradhras.imageTag" . -}}
{{- if not (and (regexMatch "^v?[0-9]+\\.[0-9]+\\.[0-9]+" $tag) (semverCompare ">=1.9.0-beta.25" $tag)) -}}
{{- fail (printf "\n\nERROR: caradhras.builtInAdminPassword.enabled is true but the Caradhras image tag %q does not read it.\n   Caradhras reads builtInAdminPassword from 1.9.0-beta.25 on; older images seed the public default password.\n   Set caradhras.image.tag to a semver tag and pin a Caradhras tag >= 1.9.0-beta.25 (a digest or latest cannot be checked).\n" $tag) -}}
{{- end -}}
```

**After (v11.0.1):**

```yaml
{{- define "plugin-caradhras.builtInAdminPasswordEnv" -}}
{{- $bp := .Values.caradhras.builtInAdminPassword | default dict -}}
{{- $tag := regexReplaceAll "@.*$" (include "caradhras.imageTag" .) "" -}}
{{- if not (and (regexMatch "^v?[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$" $tag) (semverCompare ">=1.9.0-beta.25" $tag)) -}}
{{- fail (printf "\n\nERROR: caradhras.builtInAdminPassword.enabled is true but the Caradhras image tag %q does not read it.\n   Caradhras reads builtInAdminPassword from 1.9.0-beta.25 on; older images seed the public default password.\n   Set caradhras.image.tag to a semver tag and pin a Caradhras tag >= 1.9.0-beta.25 (a bare digest or latest cannot be checked).\n" $tag) -}}
{{- end -}}
```

**Operational impact:**

- **No action required:** Existing deployments using semver tags (e.g., `1.9.0`, `1.10.0`) continue to work unchanged
- **Digest tags now supported:** If you previously avoided digest-pinned images due to validation errors, you can now use them safely

**Example: Digest-pinned image**

This configuration now passes validation in v11.0.1 (it would have failed in v11.0.0):

```yaml
caradhras:
  image:
    tag: "1.9.0@sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
  builtInAdminPassword:
    enabled: true
```

The chart strips `@sha256:...`, validates `1.9.0` against the `>=1.9.0-beta.25` requirement, and proceeds.

**Example: Prerelease tag**

This configuration now works correctly (the regex previously did not match prerelease identifiers):

```yaml
caradhras:
  image:
    tag: "1.10.0-rc.1"
  builtInAdminPassword:
    enabled: true
```

> **Note:** The validation still rejects bare digest tags without a semver prefix (e.g., `sha256:abc123...`) and the `latest` tag, as the chart cannot determine the Caradhras version from those references. Always include a semver tag component when using `builtInAdminPassword.enabled: true`.

> **Important:** If you use a digest-pinned image, ensure the semver portion of the tag (before the `@`) accurately reflects the image version. The chart trusts the tag you provide and does not verify it against the actual image manifest.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.0.1
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager -n midaz-plugins --version 11.0.1
```
<!-- {% endraw %} -->
