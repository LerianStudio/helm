# Helm Upgrade from v3.0.0 to v3.0.1

## Topics

- **[Fixes](#fixes)**
  - [Readiness probe path configuration](#readiness-probe-path-configuration)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### Readiness probe path configuration

This patch release adds explicit health check paths to the readiness probe configuration for all four service components: `pix`, `inbound`, `outbound`, and `reconciliation`.

**What changed:**

Previously, the `readinessProbe` configuration for each service was an empty object, relying on chart template defaults. Now, each service explicitly defines the health check endpoint path.

| Service | v3.0.0 | v3.0.1 |
|---------|--------|--------|
| `pix.readinessProbe` | `{}` (empty) | `path: /health` |
| `inbound.readinessProbe` | `{}` (empty) | `path: /health` |
| `outbound.readinessProbe` | `{}` (empty) | `path: /health` |
| `reconciliation.readinessProbe` | `{}` (empty) | `path: /health` |

**Why it matters:**

This change ensures consistent and explicit health check configuration across all services. The `/health` endpoint is now clearly defined in the values file, making the probe behavior more transparent and easier to customize if needed.

**Operational impact:**

If your deployment was already using the chart's default health check path, this change will have **no runtime impact** — the probes will continue to use the same endpoint. This is purely a configuration clarification that makes the default behavior explicit.

**Example configuration (v3.0.1):**

```yaml
pix:
  readinessProbe:
    path: /health

inbound:
  readinessProbe:
    path: /health

outbound:
  readinessProbe:
    path: /health

reconciliation:
  readinessProbe:
    path: /health
```

> **Note:** If you have previously overridden `readinessProbe` settings in your custom values file, your overrides will continue to take precedence. Review your custom values to ensure they remain compatible with this explicit path configuration.

**No action required** unless you need to customize the health check path. If you want to use a different endpoint, override the path in your values file:

```yaml
pix:
  readinessProbe:
    path: /custom-health-endpoint
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.0.1 -n plugin-br-pix-indirect-btg
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-pix-indirect-btg oci://registry-1.docker.io/lerianstudio/plugin-br-pix-indirect-btg-helm --version 3.0.1 -n plugin-br-pix-indirect-btg
```
