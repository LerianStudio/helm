<!-- {% raw %} -->
# Helm Upgrade from v3.4.3 to v3.4.4

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. RabbitMQ definitions JSON encoding correction](#1-rabbitmq-definitions-json-encoding-correction)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.4.3` to `3.4.4`. This is a **patch** release that fixes a JSON encoding issue in the RabbitMQ definitions secret template.

The application version (`appVersion: 3.1.1`) is unchanged. No breaking changes, no required `values.yaml` modifications, and no data migration are needed.

## Fixes

### 1. RabbitMQ definitions JSON encoding correction

The `manager/secrets_rabbitmq_definitions.yaml` template previously used `toJson` to encode the RabbitMQ definitions structure before base64 encoding. This function applies HTML escaping to certain characters (e.g., `<`, `>`, `&`), which can cause issues when RabbitMQ parses the definitions file.

The template now uses `toRawJson`, which produces valid JSON without HTML escaping.

**Before (v3.4.3):**

```yaml
data:
  load_definition.json: {{ $defs | toJson | b64enc | quote }}
```

**After (v3.4.4):**

```yaml
data:
  load_definition.json: {{ $defs | toRawJson | b64enc | quote }}
```

| Setting | v3.4.3 | v3.4.4 |
|---------|--------|--------|
| RabbitMQ definitions encoding function | `toJson` (with HTML escaping) | `toRawJson` (without HTML escaping) |

> **Note:** This change only affects deployments where `externalRabbitmqDefinitions.enabled` is `true`. If you are using an external RabbitMQ instance without chart-managed definitions, this fix has no operational impact.

**Why this matters:**

If your RabbitMQ definitions contain characters that are HTML-escaped by `toJson` (such as `<`, `>`, `&` in queue names, exchange names, or binding arguments), the resulting JSON may be malformed or incorrectly parsed by RabbitMQ. The `toRawJson` function ensures the JSON is valid and unescaped.

**Operational impact:**

When you upgrade, Helm will update the `fetcher-manager-rabbitmq-definitions` secret with the corrected JSON encoding. If the manager pod is configured to load definitions from this secret, it will pick up the new content on the next restart or when the secret is reloaded.

> **Important:** If your existing RabbitMQ definitions do not contain any HTML-escapable characters, the functional output of `toJson` and `toRawJson` will be identical, and you will see no behavioral change. This fix is a preventive correction to ensure compatibility with all valid RabbitMQ definition structures.

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will update the RabbitMQ definitions secret with the corrected encoding.

**Recommended upgrade process:**

1. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).
2. Run the upgrade command during a maintenance window.
3. Verify the manager pods are healthy after the upgrade:

```bash
kubectl get pods -n fetcher -l app.kubernetes.io/component=manager
```

4. If you are using chart-managed RabbitMQ definitions, verify the secret was updated:

```bash
kubectl get secret -n fetcher fetcher-manager-rabbitmq-definitions -o jsonpath='{.data.load_definition\.json}' | base64 -d | jq .
```

5. Check manager logs for any RabbitMQ connection or definition loading errors:

```bash
kubectl logs -n fetcher -l app.kubernetes.io/component=manager --tail=50
```

> **Note:** If you are not using `externalRabbitmqDefinitions.enabled: true`, this upgrade will have no visible effect on your deployment.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.4.4 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.4.4 -n fetcher
```
<!-- {% endraw %} -->
