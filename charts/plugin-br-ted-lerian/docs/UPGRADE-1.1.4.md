# Helm Upgrade from v1.1.3 to v1.1.4

## Topics

- **[Overview](#overview)**
- **[Ingress Hostname Change](#ingress-hostname-change)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Overview

This is a patch release that updates the default ingress hostname to use a generic example domain instead of a specific production domain.

| Setting | v1.1.3 | v1.1.4 |
|---------|--------|--------|
| Chart version | `1.1.3` | `1.1.4` |
| App version | `1.0.0-beta.64` | `1.0.0-beta.64` |

**What changed:**
- Default ingress hostname changed from `plugin-br-ted-lerian.lerian.net` to `plugin-br-ted-lerian.example.com`

**What stayed the same:**
- Application version remains `1.0.0-beta.64`
- All other values.yaml defaults unchanged
- All template files unchanged
- All configuration parameters unchanged

**Impact:** This upgrade requires no action if you have already overridden the ingress hostname in your values file. If you are using the default hostname, you should explicitly set your desired hostname before upgrading.

---

## Ingress Hostname Change

The default ingress hostname has been changed to use a generic example domain. This change only affects deployments that rely on the chart's default hostname value.

| Setting | v1.1.3 | v1.1.4 |
|---------|--------|--------|
| Default ingress host | `plugin-br-ted-lerian.lerian.net` | `plugin-br-ted-lerian.example.com` |

**Before (v1.1.3):**
```yaml
plugin-br-ted-lerian:
  ingress:
    enabled: true
    className: ""
    annotations: {}
    hosts:
      - host: "plugin-br-ted-lerian.lerian.net"
        paths:
          - path: /
            pathType: Prefix
```

**After (v1.1.4):**
```yaml
plugin-br-ted-lerian:
  ingress:
    enabled: true
    className: ""
    annotations: {}
    hosts:
      - host: "plugin-br-ted-lerian.example.com"
        paths:
          - path: /
            pathType: Prefix
```

### Action Required

If you are currently using the default hostname (`plugin-br-ted-lerian.lerian.net`), you must explicitly set your desired hostname in your values file before upgrading:

**Option 1: Keep your existing hostname**

Add the following to your values file or Helm upgrade command:

```yaml
plugin-br-ted-lerian:
  ingress:
    hosts:
      - host: "plugin-br-ted-lerian.lerian.net"
        paths:
          - path: /
            pathType: Prefix
```

Or via command line:

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm \
  --namespace plugin-br-ted-lerian \
  --version 1.1.4 \
  --set plugin-br-ted-lerian.ingress.hosts[0].host="plugin-br-ted-lerian.lerian.net"
```

**Option 2: Use your own custom hostname**

Set your production hostname in your values file:

```yaml
plugin-br-ted-lerian:
  ingress:
    hosts:
      - host: "your-domain.example.com"
        paths:
          - path: /
            pathType: Prefix
```

> **Note:** If you have already overridden the ingress hostname in your values file, no action is required. The upgrade will preserve your existing configuration.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.1.4
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.1.4
```
