<!-- {% raw %} -->
# Helm Upgrade from v11.0.0 to v11.0.1

## Topics

- **[Changes](#changes)**
  - [1. The built-in admin password check reads a tag with a digest](#1-the-built-in-admin-password-check-reads-a-tag-with-a-digest)
- **[Action required](#action-required)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Changes

### 1. The built-in admin password check reads a tag with a digest

With `caradhras.builtInAdminPassword.enabled: true`, the chart checks that `caradhras.image.tag` is `1.9.0-beta.25` or later. In v11.0.0, a tag with a digest suffix, such as `2.1.0@sha256:...`, failed the render with `invalid semantic version`. In v11.0.1, the check reads the version before the `@`:

| `caradhras.image.tag` | v11.0.0 | v11.0.1 |
|---|---|---|
| `2.1.0@sha256:...` | Render fails: `invalid semantic version` | Renders |
| `1.8.6@sha256:...` | Render fails: `invalid semantic version` | Render fails: the tag does not read `builtInAdminPassword` |
| `sha256:...` (bare digest) or `latest` | Render fails: the tag does not read `builtInAdminPassword` | Same as v11.0.0 |
| `1.9.0-beta.25`, `2.1.0` | Renders | Same as v11.0.0 |

With `caradhras.builtInAdminPassword.enabled: false`, the default, nothing changes.

## Action required

None. The rendered manifests are the same as v11.0.0 except for the `helm.sh/chart` label and what follows from it: the pod-template checksums that hash a chart ConfigMap or Secret with that label change. The `auth` and `identity` ConfigMaps always carry the label, and the `caradhras` pod template also hashes the `auth` ConfigMap, so the `auth`, `identity` and `caradhras` pods restart once, with the usual rolling update.

## Preview changes before upgrading

The commands below are examples. Replace `plugin-access-manager` (release name) and `-n midaz-plugins` (namespace) with the values used at install time.

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 11.0.1 -n midaz-plugins
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 11.0.1 -n midaz-plugins
```
<!-- {% endraw %} -->
