<!-- {% raw %} -->
# Helm Upgrade from v1.1.3 to v1.1.4

## Topics

- **[Overview](#overview)**
- **[Before you upgrade](#before-you-upgrade)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**
- **[Verify](#verify)**

---

## Overview

This patch release changes one `values.yaml` default: the placeholder ingress host. It changes no template and no application image.

| Setting | v1.1.3 | v1.1.4 |
|---------|--------|--------|
| Chart version | `1.1.3` | `1.1.4` |
| App version | `1.0.0-beta.64` | `1.0.0-beta.64` |

**What changed:**
- The placeholder default for `plugin-br-ted-lerian.ingress.hosts[0].host` is now `plugin-br-ted-lerian.example.com`

**What stayed the same:**
- `plugin-br-ted-lerian.ingress.enabled` keeps its default (`true`)
- Application version remains `1.0.0-beta.64`
- All template files are unchanged

**Impact:**
- If your values file sets `plugin-br-ted-lerian.ingress.hosts`, the Ingress host is the same as in v1.1.3. No action is required.
- If you relied on the previous placeholder host, the Ingress now renders with `plugin-br-ted-lerian.example.com`. Set your own host before you upgrade.
- The chart `helm.sh/chart` label changes on the Deployment and other top-level resources. It is not part of the pod template (since v1.1.3), so pods do not restart.

---

## Before you upgrade

Skip this step if your values file already sets `plugin-br-ted-lerian.ingress.hosts`, or if you set `plugin-br-ted-lerian.ingress.enabled: false`.

Otherwise, add your host to your values file:

```yaml
plugin-br-ted-lerian:
  ingress:
    hosts:
      - host: "<your-host>"
        paths:
          - path: /
            pathType: Prefix
```

Without `-f`, Helm reuses the values of the last release and ignores your edit.

---

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.1.4
```

If you added a host above, append `--reuse-values -f <your-values.yaml>` to this command.

If you set your own host, the Ingress `host` shows no change. If it shows `plugin-br-ted-lerian.example.com` and you use the Ingress, set your host as described above.

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade plugin-br-ted-lerian oci://ghcr.io/lerianstudio/plugin-br-ted-lerian-helm --namespace plugin-br-ted-lerian --version 1.1.4
```

If you added a host above, append `--reuse-values -f <your-values.yaml>` to this command.

---

## Verify

```bash
kubectl get ingress -n plugin-br-ted-lerian
helm list -n plugin-br-ted-lerian
```

If ingress is enabled, the Ingress host is your own host. The release shows chart `plugin-br-ted-lerian-helm-1.1.4`.
<!-- {% endraw %} -->
