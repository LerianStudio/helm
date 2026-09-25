# Helm Upgrade from v0.4.2 to v0.4.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. Removed Obsolete Image Name Reference from NOTES.txt](#1-removed-obsolete-image-name-reference-from-notestxt)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that removes an obsolete reference from the installation notes. No configuration changes, template modifications, or value updates are required.

| Setting | v0.4.2 | v0.4.3 |
|---------|--------|--------|
| Chart Version | 0.4.2 | 0.4.3 |
| Template Changes | None | NOTES.txt only |
| Configuration Changes | None | None |

## Fixes

### 1. Removed Obsolete Image Name Reference from NOTES.txt

The post-install notes displayed during `helm install` or `helm upgrade` contained a stale reference to the plugin's previous image name (`plugin-br-pix-direct-jd:v1.11.0`). This reference was no longer accurate and has been removed.

**Before (v0.4.2):**

```yaml
{{ if eq .Chart.AppVersion "0.0.0-unreleased" -}}
!! appVersion is a PLACEHOLDER and NO IMAGE EXISTS AT THAT TAG.
   Nothing has been published under the name `plugin-br-pix-jd` yet — the plugin's
   latest release is `plugin-br-pix-direct-jd:v1.11.0`, under the previous name.
   Pods will sit in ImagePullBackOff until you pin a real tag:
     --set api.image.tag=<tag>
{{ end -}}
```

**After (v0.4.3):**

```yaml
{{ if eq .Chart.AppVersion "0.0.0-unreleased" -}}
!! appVersion is a PLACEHOLDER and NO IMAGE EXISTS AT THAT TAG.
   Pods will sit in ImagePullBackOff until you pin a real tag:
     --set api.image.tag=<tag>
{{ end -}}
```

**Operational impact:**

This change only affects the text displayed in the terminal after installation when `appVersion` is set to `0.0.0-unreleased`. It does not modify any deployed resources, configuration, or runtime behavior.

> **Note:** If you have already pinned a valid `api.image.tag` in your values file, this warning does not appear and the change has no visible effect.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.4.3 -n plugin-br-pix-jd
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-jd oci://registry-1.docker.io/lerianstudio/plugin-br-pix-jd-helm --version 0.4.3 -n plugin-br-pix-jd
```
