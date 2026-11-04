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

To check whether you set a host, run `helm get values plugin-br-ted-lerian -n plugin-br-ted-lerian`. If the output has no `plugin-br-ted-lerian.ingress.hosts`, the release uses the chart default. If you use the Ingress, do the step in Before you upgrade.

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

If you set a host, the Ingress shows your host. The release shows chart `plugin-br-ted-lerian-helm-1.1.4`.
<!-- {% endraw %} -->
