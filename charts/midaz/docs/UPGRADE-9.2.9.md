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

The Job only ran for external RabbitMQ instances. The bundled RabbitMQ got its users from the static `files/rabbitmq/load_definitions.json`, which declared `midaz`, `transaction` and `consumer` with one fixed password hash published in the chart, all tagged `administrator`.

**After (v9.2.9):**

When using the bundled RabbitMQ:
- The Job logs in as the `transaction` user (an administrator) using the password from the ledger Secret
- It creates/updates both `transaction` and `consumer` users with the passwords from `ledger.secrets.RABBITMQ_DEFAULT_PASS` and `ledger.secrets.RABBITMQ_CONSUMER_PASS`
- It applies the full RabbitMQ definitions (exchanges, queues, bindings, permissions)
- It removes the legacy `midaz` user if present (created by older chart versions)

#### Configuration

The Job automatically detects bundled vs. external RabbitMQ. With the bundled RabbitMQ, review the **Action required** items below before upgrading.

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

#### Action required (bundled RabbitMQ)

1. **Release not named `midaz`:** the Job reaches the broker at `global.externalRabbitmqDefinitions.connection.host`, whose default is `midaz-rabbitmq`, even for the bundled broker. The bundled broker's Service is named `<release>-rabbitmq`, so with any other release name the Job's `wait-for-dependencies` init container times out and the `pre-upgrade` hook fails the upgrade. Point the Job at your broker before upgrading:

   ```yaml
   global:
     externalRabbitmqDefinitions:
       connection:
         host: "<release>-rabbitmq"
   ```

2. **The `midaz` broker user is deleted:** on every run the Job calls `DELETE /api/users/midaz`. Anything that still logs in to the bundled broker as `midaz` (management UI access, scripts, other applications) stops working. Move it to its own user first.

3. **Rotate the RabbitMQ passwords:** until v9.2.8 the bundled broker's users carried the fixed password hash shipped in the chart, so in a working install the ledger's `RABBITMQ_DEFAULT_PASS` and `RABBITMQ_CONSUMER_PASS` are that published password. Set new values in `ledger.secrets` (see [Fix #3](#3-improved-rabbitmq-password-rotation-handling)).

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
# Static file whose users (midaz, transaction, consumer) share one fixed password hash
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

> **Note:** The bundled RabbitMQ imports this Secret at every boot. A password change in `ledger.secrets` reaches the running broker through the bootstrap Job (automatic during `helm upgrade`); no broker restart is needed. A later broker restart re-imports the Secret, which already holds the new passwords.

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

When using bundled RabbitMQ, the Job logs in as `transaction` with:
1. `RABBITMQ_APPLIED_PASS`, the `transaction-password` key of the `midaz-rabbitmq-load-definition` Secret (the password the chart last gave the broker), when that key exists
2. otherwise `RABBITMQ_ADMIN_PASS`, the `RABBITMQ_DEFAULT_PASS` key of the ledger Secret. This is the path on the first upgrade from v9.2.8 or earlier, whose Secret has no `transaction-password` key.

It then sets `transaction` and `consumer` to the passwords from the new values. Because the `pre-upgrade` hook runs before Helm updates the Secrets, both are still the previous release's values at that point.

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

3. If the bootstrap Job fails with HTTP 401, restart the RabbitMQ pod (this drops queued messages; the bundled broker has no persistent volume):

```bash
kubectl delete pod <release>-rabbitmq-0 -n midaz
```

4. Re-run the upgrade:

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.2.9 -n midaz
```

5. Restart the ledger to pick up the new passwords (v9.2.9 does not restart pods when their Secret changes):

```bash
kubectl rollout restart deployment/<release>-ledger -n midaz
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
