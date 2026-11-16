# Helm Upgrade from v1.1.1 to v1.1.2

## Topics

- **[Overview](#overview)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This patch release changes no templates, no `values.yaml` defaults and no application image. It adds the CRM credential keys to `values-template.yaml` and lists them in the README.

| Setting | v1.1.1 | v1.1.2 |
|---------|--------|--------|
| Chart version | 1.1.1 | 1.1.2 |
| App version | 1.0.0-beta.64 | 1.0.0-beta.64 |

**What changed:**
- Chart version bumped from `1.1.1` to `1.1.2` in `Chart.yaml`
- `values-template.yaml` adds `plugin-br-ted-lerian.secrets.CRM_CLIENT_ID` and `plugin-br-ted-lerian.secrets.CRM_CLIENT_SECRET` (empty)
- The README lists `CRM_CLIENT_ID` and `CRM_CLIENT_SECRET` (Access Manager M2M pair) as required secrets in single-tenant mode

**What stayed the same:**
- Application version remains `1.0.0-beta.64`
- All values.yaml configuration unchanged
- All template files unchanged
- All default behaviors unchanged

**Impact:** No configuration migration is required. Your existing values files will work without modification.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.2 -n plugin-br-ted-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --version 1.1.2 -n plugin-br-ted-lerian
```
