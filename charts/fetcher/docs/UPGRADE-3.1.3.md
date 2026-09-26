# Helm Upgrade from v3.1.2 to v3.1.3

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. RabbitMQ bootstrap password security fix](#1-rabbitmq-bootstrap-password-security-fix)
- **[Configuration Changes](#configuration-changes)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This guide covers the `fetcher` chart upgrade from `3.1.2` to `3.1.3`. This is a **patch** release that fixes a critical security issue in the RabbitMQ bootstrap job where the `plugin` user password was being reset to a publicly visible hash during definition loading.

The application version (`appVersion: 3.1.0`) is unchanged. No breaking changes or data migration are needed, but operators should understand the bootstrap sequence change to avoid confusion during troubleshooting.

## Fixes

### 1. RabbitMQ bootstrap password security fix

The RabbitMQ bootstrap job previously applied definitions (including a `users` array with a password hash) **before** updating the `plugin` user with the operator-provided password from the secret. This caused the `plugin` user password to be briefly reset to the hash visible in the `load_definitions.json` file, then overwritten by the correct password. This sequence exposed a security risk and could cause authentication failures during the bootstrap window.

**Before (v3.1.2):**

```yaml
# ConfigMap included the full definitions file with users array
data:
  load_definitions.json: |
    {
      "users": [
        {
          "name": "plugin",
          "password_hash": "...",
          "tags": "administrator"
        }
      ],
      "vhosts": [...],
      "permissions": [...]
    }
```

```bash
# Job sequence (v3.1.2)
# 1. POST definitions (resets plugin password to the file's hash)
curl -X POST --data-binary @/definitions/load_definitions.json "$BASE_URL/api/definitions"

# 2. PUT plugin user (overwrites with the correct password)
curl -X PUT --data "{\"password\":\"$RABBITMQ_PLUGIN_PASS\",\"tags\":\"administrator\"}" "$BASE_URL/api/users/plugin"
```

**After (v3.1.3):**

```yaml
# ConfigMap omits the users array entirely
data:
  load_definitions.json: {{ omit (.Files.Get "files/rabbitmq/load_definitions.json" | fromJson) "users" | toJson | quote }}
```

```bash
# Job sequence (v3.1.3)
# 1. Validate password does not contain control characters
case "$RABBITMQ_PLUGIN_PASS" in *[[:cntrl:]]*)
  echo "The RabbitMQ plugin password contains a control character (newline, tab, carriage return or DEL); choose one without."
  exit 1;;
esac

# 2. PUT plugin user with JSON-escaped password (before definitions)
PASS=$(printf '%s' "$RABBITMQ_PLUGIN_PASS" | sed 's/[\\"]/\\&/g')
curl -X PUT --data "{\"password\":\"$PASS\",\"tags\":\"administrator\"}" "$BASE_URL/api/users/plugin"

# 3. POST definitions (permissions reference the already-created plugin user)
curl -X POST --data-binary @/definitions/load_definitions.json "$BASE_URL/api/definitions"
```

| Change | v3.1.2 | v3.1.3 |
|--------|--------|--------|
| ConfigMap `users` array | Included in `load_definitions.json` | Omitted via `omit` function |
| Bootstrap sequence | 1. POST definitions<br>2. PUT plugin user | 1. PUT plugin user<br>2. POST definitions |
| Password escaping | None | JSON escape for backslash and quote |
| Password validation | None | Rejects control characters (newline, tab, CR, DEL) |

> **Important:** The `plugin` user password is now created **before** the definitions are loaded. This ensures permissions referencing the `plugin` user can be applied correctly and the password is never reset to a public hash.

> **Warning:** If your `externalRabbitmqDefinitions.appCredentials.pluginPassword` or `secrets.RABBITMQ_DEFAULT_PASS` contains a newline, tab, carriage return, or DEL character, the bootstrap job will fail with an error message. Choose a password without control characters.

**Operational impact:**

- The bootstrap job will now fail fast if the password contains control characters, preventing silent authentication issues
- The `plugin` user is created with the correct password from the start, eliminating the brief window where the wrong password was active
- Permissions in the definitions file that reference the `plugin` user will apply correctly because the user exists before the definitions are loaded

## Configuration Changes

No `values.yaml` keys were added, removed, or changed. The fix is entirely in the bootstrap job template and ConfigMap data transformation.

| Setting | v3.1.2 | v3.1.3 |
|---------|--------|--------|
| `externalRabbitmqDefinitions.appCredentials.pluginPassword` | No validation | Must not contain control characters |
| `secrets.RABBITMQ_DEFAULT_PASS` | No validation | Must not contain control characters |

> **Note:** If you are using `useExistingSecret` for RabbitMQ credentials, ensure the password in your existing secret does not contain control characters (newline, tab, carriage return, or DEL).

## Migration Steps

This upgrade requires no manual migration steps. The Helm upgrade will update the `fetcher-bootstrap-rabbitmq-definitions` ConfigMap and the `fetcher-bootstrap-rabbitmq` Job template.

**Recommended upgrade process:**

1. Verify your RabbitMQ `plugin` user password does not contain control characters:

```bash
# If using values.yaml
grep -E "pluginPassword|RABBITMQ_DEFAULT_PASS" values.yaml

# If using existing secret
kubectl get secret -n fetcher your-rabbitmq-secret -o jsonpath='{.data.RABBITMQ_DEFAULT_PASS}' | base64 -d | cat -A
```

> **Note:** The `cat -A` command will show control characters as `^I` (tab), `^M` (carriage return), `$` (newline), etc. If you see any of these, generate a new password without control characters.

2. If your password contains control characters, generate a new one and update your `values.yaml` or existing secret:

```bash
# Generate a secure password without control characters
openssl rand -base64 32 | tr -d '\n'
```

```yaml
# Update values.yaml
externalRabbitmqDefinitions:
  appCredentials:
    pluginPassword: "your-new-password-without-control-chars"

secrets:
  RABBITMQ_DEFAULT_PASS: "your-new-password-without-control-chars"
```

3. Review the changes using the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

4. Run the upgrade command. The bootstrap job will run again with the new logic.

5. Verify the bootstrap job completed successfully:

```bash
kubectl get jobs -n fetcher -l app.kubernetes.io/component=bootstrap-rabbitmq
kubectl logs -n fetcher -l job-name=fetcher-bootstrap-rabbitmq --tail=100
```

6. Confirm the `plugin` user can authenticate to RabbitMQ:

```bash
# Port-forward to RabbitMQ management UI
kubectl port-forward -n fetcher svc/fetcher-rabbitmq 15672:15672

# Test authentication (replace with your plugin password)
curl -u plugin:your-plugin-password http://localhost:15672/api/whoami
```

> **Note:** The bootstrap job is a Kubernetes Job resource that runs to completion. If the job already succeeded in a previous release, Helm will replace it with a new job that runs again during the upgrade.

## Preview changes before upgrading

```bash
helm diff upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.3 -n fetcher
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade fetcher oci://registry-1.docker.io/lerianstudio/fetcher-helm --version 3.1.3 -n fetcher
```
