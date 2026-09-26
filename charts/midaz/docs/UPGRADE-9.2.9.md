# Helm Upgrade from v9.2.8 to v9.2.9

## Topics

- **[Fixes](#fixes)**
  - [1. RabbitMQ bootstrap job now supports bundled RabbitMQ](#1-rabbitmq-bootstrap-job-now-supports-bundled-rabbitmq)
  - [2. Bundled RabbitMQ load definitions now include user credentials](#2-bundled-rabbitmq-load-definitions-now-include-user-credentials)
  - [3. Improved RabbitMQ password rotation handling](#3-improved-rabbitmq-password-rotation-handling)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. RabbitMQ bootstrap job now supports bundled RabbitMQ

The `bootstrap-rabbitmq` Job previously only ran when `global.externalRabbitmqDefinitions.enabled` was `true`. It now also runs automatically when the bundled RabbitMQ is enabled (`rabbitmq.enabled: true` and `ledger.enabled: true`), eliminating the need for manual RabbitMQ user and permission setup.

#### What changed

| Setting | v9.2.8 | v9.2.9 |
|---------|--------|--------|
| Job trigger condition | Only `global.externalRabbitmqDefinitions.enabled: true` | `global.externalRabbitmqDefinitions.enabled: true` OR bundled RabbitMQ enabled |
| Admin credentials source (bundled) | N/A | Reads from ledger Secret (`RABBITMQ_DEFAULT_PASS`) |
| Admin user (bundled) | N/A | `transaction` |

#### How it works

**Before (v9.2.8):**

The Job only created users and permissions for external RabbitMQ instances. Bundled RabbitMQ required manual configuration.

**After (v9.2.9):**

When using the bundled RabbitMQ:
- The Job logs in as the `transaction` user (an administrator) using the password from the ledger Secret
- It creates/updates both `transaction` and `consumer` users with the passwords from `ledger.secrets.RABBITMQ_DEFAULT_PASS` and `ledger.secrets.RABBITMQ_CONSUMER_PASS`
- It applies the full RabbitMQ definitions (exchanges, queues, bindings, permissions)
- It removes the legacy `midaz` user if present (created by older chart versions)

#### Configuration

No action required for most deployments. The Job automatically detects bundled vs. external RabbitMQ.

For bundled RabbitMQ, ensure these secrets are set:

```yaml
ledger:
  secrets:
    RABBITMQ_DEFAULT_PASS: "your-transaction-password"
    RABBITMQ_CONSUMER_PASS: "your-consumer-password"
```

> **Important:** If you use `ledger.useExistingSecret: true` with the bundled RabbitMQ, the chart must read passwords from your existing Secret at render time. This requires cluster access during `helm install` or `helm upgrade`. Argo CD and `helm template` (without `--dry-run=server`) will fail because they render without cluster access. Either:
> - Use `ledger.useExistingSecret: false` and set passwords in `ledger.secrets`, or
> - Ensure your CI/CD pipeline renders with cluster access (`helm upgrade` or `helm install --dry-run=server`)

### 2. Bundled RabbitMQ load definitions now include user credentials

The `midaz-rabbitmq-load-definition` Secret, which the bundled RabbitMQ imports at boot, now includes user credentials directly in the definitions file.

#### What changed

| Setting | v9.2.8 | v9.2.9 |
|---------|--------|--------|
| Definitions file content | Static file from `files/rabbitmq/load_definitions.json` | Dynamically generated with user credentials |
| User creation | Manual or via bootstrap Job | Automatic at RabbitMQ boot |
| Password source | N/A | `ledger.secrets.RABBITMQ_DEFAULT_PASS` and `RABBITMQ_CONSUMER_PASS` |

**Before (v9.2.8):**

```yaml
# Static file with no users
data:
  load_definition.json: |
    {{ .Files.Get "files/rabbitmq/load_definitions.json" | b64enc }}
```

**After (v9.2.9):**

```yaml
# Dynamically generated with users
data:
  load_definition.json: {{ $defs | toJson | b64enc | quote }}
  transaction-password: {{ $pass.RABBITMQ_DEFAULT_PASS | b64enc | quote }}
```

The definitions now include:

```yaml
{
  "users": [
    {
      "name": "transaction",
      "password": "<from ledger.secrets.RABBITMQ_DEFAULT_PASS>",
      "tags": "administrator"
    },
    {
      "name": "consumer",
      "password": "<from ledger.secrets.RABBITMQ_CONSUMER_PASS>",
      "tags": "administrator"
    }
  ],
  "permissions": [...],
  "exchanges": [...],
  "queues": [...]
}
```

#### Operational impact

- RabbitMQ now creates users automatically at boot with the passwords from the ledger Secret
- The bootstrap Job (see [Fix #1](#1-rabbitmq-bootstrap-job-now-supports-bundled-rabbitmq)) ensures users and permissions stay in sync after boot
- The Secret includes a `transaction-password` key that the bootstrap Job reads to detect password drift (see [Fix #3](#3-improved-rabbitmq-password-rotation-handling))

> **Note:** The bundled RabbitMQ imports definitions only at boot. Changing passwords in `ledger.secrets` requires both:
> 1. Running the bootstrap Job (automatic during `helm upgrade`)
> 2. Restarting the RabbitMQ pod to import the new definitions Secret

### 3. Improved RabbitMQ password rotation handling

The bootstrap Job now detects and handles password mismatches between the ledger Secret and the running RabbitMQ broker.

#### What changed

| Feature | v9.2.8 | v9.2.9 |
|---------|--------|--------|
| Password mismatch detection | None | Checks `RABBITMQ_APPLIED_PASS` from definitions Secret |
| Error message on 401 | Generic authentication failure | Detailed instructions for bundled RabbitMQ |
| Admin password update | Not handled | Updates login password mid-script when changing own password |

#### How it works

**Password drift detection:**

When using bundled RabbitMQ, the Job reads two passwords:
1. `RABBITMQ_ADMIN_PASS` from the ledger Secret (the password the chart wants to apply)
2. `RABBITMQ_APPLIED_PASS` from the `midaz-rabbitmq-load-definition` Secret (the password the broker currently holds)

If they differ, the Job uses `RABBITMQ_APPLIED_PASS` to log in, then updates the broker with the new password.

**Error handling:**

If the Job receives HTTP 401 (authentication failure), it now provides actionable guidance:

```bash
RabbitMQ refused the login of user transaction (HTTP 401). The broker holds another password than the one this chart gave it: restart the broker pod (midaz-rabbitmq-0, which boots with the chart's passwords and drops queued messages), then upgrade or sync again. Once that succeeds, restart the ledger, whose pods keep the password they started with: kubectl -n <namespace> rollout restart deployment/midaz-ledger
```

> **Warning:** Restarting the RabbitMQ pod drops all queued messages. Ensure your application can tolerate message loss or drain queues before restarting.

#### Migration steps for password rotation

If you need to rotate RabbitMQ passwords:

1. Update the passwords in your values:

```yaml
ledger:
  secrets:
    RABBITMQ_DEFAULT_PASS: "new-transaction-password"
    RABBITMQ_CONSUMER_PASS: "new-consumer-password"
```

2. Run the upgrade:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.9 -n midaz
```

3. If the bootstrap Job fails with HTTP 401, restart the RabbitMQ pod:

```bash
kubectl delete pod midaz-rabbitmq-0 -n midaz
```

4. Re-run the upgrade:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.9 -n midaz
```

5. Restart the ledger to pick up the new passwords:

```bash
kubectl rollout restart deployment/midaz-ledger -n midaz
```

#### Template changes

**Before (v9.2.8):**

```yaml
- name: RABBITMQ_ADMIN_PASS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.externalRabbitmqDefinitions.rabbitmqAdminLogin.useExistingSecret.name | quote }}
      key: RABBITMQ_ADMIN_PASS
```

**After (v9.2.9):**

```yaml
- name: RABBITMQ_ADMIN_PASS
  valueFrom:
    secretKeyRef:
      name: {{ $adminSecret | quote }}
      key: {{ if $bundled }}RABBITMQ_DEFAULT_PASS{{ else }}RABBITMQ_ADMIN_PASS{{ end }}
- name: RABBITMQ_APPLIED_PASS
  valueFrom:
    secretKeyRef:
      name: midaz-rabbitmq-load-definition
      key: transaction-password
      optional: true
```

The Job now reads both the desired password (`RABBITMQ_ADMIN_PASS`) and the currently applied password (`RABBITMQ_APPLIED_PASS`) to handle drift gracefully.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.9 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.9 -n midaz
```
