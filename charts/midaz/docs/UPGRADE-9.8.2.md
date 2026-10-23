<!-- {% raw %} -->
# Helm Upgrade from v9.8.1 to v9.8.2

## Topics

- **[Fixes](#fixes)**
  - [1. RabbitMQ load definition JSON encoding](#1-rabbitmq-load-definition-json-encoding)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. RabbitMQ load definition JSON encoding

The RabbitMQ load definition ConfigMap now uses `toRawJson` instead of `toJson` when encoding the broker definitions. This fixes a critical issue where placeholder values in passwords (e.g., `<path:...>` for external secret injection) were being HTML-escaped, preventing them from resolving correctly.

| Setting | v9.8.1 | v9.8.2 |
|---------|--------|--------|
| JSON encoding function | `toJson` | `toRawJson` |

**Why this matters:**

When using external secret management systems (e.g., Vault, AWS Secrets Manager) with placeholder syntax like `<path:vault/data/rabbitmq#password>`, the `toJson` function escapes `<` and `>` characters to `\u003c` and `\u003e`. This prevents the secret injection system from recognizing and resolving the placeholder, causing RabbitMQ authentication to fail with the literal escaped string instead of the actual password.

**Before (v9.8.1):**

```yaml
data:
  {{- /* The bundled broker imports this at every boot: a permission for a user the file lacks fails the boot. */}}
  load_definition.json: {{ $defs | toJson | b64enc | quote }}
```

**After (v9.8.2):**

```yaml
data:
  {{- /* The bundled broker imports this at every boot: a permission for a user the file lacks fails the boot.
       toRawJson keeps < and > as is: toJson escapes them, so a <path:...> placeholder in the passwords never resolves. */}}
  load_definition.json: {{ $defs | toRawJson | b64enc | quote }}
```

**Operational impact:**

- **If you are NOT using external secret placeholders:** This change has no effect. The RabbitMQ load definition will continue to work as before.
- **If you ARE using external secret placeholders in RabbitMQ passwords:** This fix ensures your placeholders are preserved correctly and can be resolved by your secret injection system. If you previously worked around this issue by escaping the placeholders or using alternative syntax, you can now use the standard `<path:...>` format.

> **Note:** This is a patch-level fix with no breaking changes. The upgrade will trigger a ConfigMap update, but RabbitMQ will reimport the definitions on next boot without disruption if the definitions themselves have not changed.

> **Important:** If you have been unable to use external secret placeholders in RabbitMQ passwords due to this escaping issue, you can now migrate to using them. Ensure your secret injection system is configured correctly before upgrading.

#### Action required

No action is required for most operators. If you previously encountered issues with external secret placeholders in RabbitMQ passwords being escaped, verify that your secret injection system is configured and the placeholders are in the correct format before upgrading:

```yaml
# Example: Using Vault placeholder syntax
rabbitmq:
  auth:
    password: "<path:vault/data/rabbitmq#password>"
```

After upgrading, the placeholder will be preserved in the load definition and resolved by your secret injection system at runtime.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.8.2 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.8.2 -n midaz
```
<!-- {% endraw %} -->
