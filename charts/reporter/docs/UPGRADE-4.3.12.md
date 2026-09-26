# Helm Upgrade from v4.3.11 to v4.3.12

## Topics

- **[Overview](#overview)**
- **[Fixes](#fixes)**
  - [1. The bundled RabbitMQ broker now requires a custom password](#1-the-bundled-rabbitmq-broker-now-requires-a-custom-password)
  - [2. The bundled broker now seeds its user from plaintext instead of a hash](#2-the-bundled-broker-now-seeds-its-user-from-plaintext-instead-of-a-hash)
  - [3. Weak passwords are refused at render time](#3-weak-passwords-are-refused-at-render-time)
- **[Configuration Changes](#configuration-changes)**
- **[Who is affected](#who-is-affected)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This is a patch release that removes the fixed development credential from the bundled RabbitMQ broker (`rabbitmq.enabled: true`) and requires operators to set a custom password before installing or upgrading. The bundled broker's user-seeding mechanism has changed from a pre-computed salted hash to plaintext password import, eliminating the coupled password/hash pair that could not be customized safely.

If you do not enable the bundled RabbitMQ subchart (the chart default is `rabbitmq.enabled: false`, and every Lerian-operated tier uses an external broker), this release does not affect you beyond requiring that `secrets.RABBITMQ_DEFAULT_PASS` be set to a non-empty value.

| Field | v4.3.11 | v4.3.12 |
|-------|---------|---------|
| Chart version | `4.3.11` | `4.3.12` |
| App version | `4.2.0` | `4.2.0` |
| `secrets.RABBITMQ_DEFAULT_PASS` default | `"reporter123"` (fixed dev credential) | `""` (empty — must be set) |
| `rabbitmq.loadDefinition.passwordHash` | present, required when `rabbitmq.enabled` | **removed** |
| Bundled broker user seeding | salted `password_hash` in load_definitions | plaintext `password` in load_definitions |

## Fixes

### 1. The bundled RabbitMQ broker now requires a custom password

**What changed:**

The default value of `secrets.RABBITMQ_DEFAULT_PASS` changed from `"reporter123"` to `""` (empty string). An empty value now fails the render with an error that names the key and explains what to do.

**Before (v4.3.11):**

```yaml
secrets:
  RABBITMQ_DEFAULT_PASS: "reporter123"
```

**After (v4.3.12):**

```yaml
secrets:
  RABBITMQ_DEFAULT_PASS: ""
```

The render error when the value is empty:

```text
Error: execution error at (reporter/templates/manager/secrets.yaml): secrets.RABBITMQ_DEFAULT_PASS is required. With the bundled broker it is the broker's only login; when it replaces the reporter123 of earlier versions, restart the broker after the upgrade: kubectl -n <namespace> rollout restart statefulset/<release-name>-rabbitmq
```

**Why this matters:**

The bundled broker shipped with a **fixed, publicly documented development credential** (`reporter123`) that was printed in `values.yaml` and in every prior version of this upgrade guide. That credential was safe only in local development environments where the broker is not network-accessible. Leaving it as the default for `helm install` meant an operator could deploy the chart without overriding the password and reach a running installation with a known credential — a footgun for any environment where the broker's management API or AMQP port is reachable.

The v4.3.11 mechanism made customizing the password unsafe: the broker seeded its user from a pre-computed salted hash (`rabbitmq.loadDefinition.passwordHash`), and Helm cannot derive RabbitMQ's `rabbit_password_hashing_sha256` hash from a plaintext password. An operator who set a custom `RABBITMQ_DEFAULT_PASS` without also computing and setting the matching `passwordHash` would have rendered a chart where the workloads authenticated with one password and the broker expected another — a configuration that passed `helm template` but failed at runtime with a 403. To prevent that footgun, v4.3.11 **refused** any override of either value and required operators to use an external broker (`rabbitmq.enabled=false`) for custom credentials.

v4.3.12 removes the hash, seeds the broker user from the plaintext password, and requires that password to be set. The bundled broker is no longer locked to a fixed credential.

**What operators need to do:**

Set `secrets.RABBITMQ_DEFAULT_PASS` to a custom value in your `values.yaml` or via `--set`. The password must not be empty, and it must not be any of the weak passwords printed in this chart: `reporter123`, `Lerian@123`, or `CHANGE_ME`. Those three strings are refused at render time (see [item 3](#3-weak-passwords-are-refused-at-render-time)).

```yaml
secrets:
  RABBITMQ_DEFAULT_PASS: "your-custom-password-here"
```

> **Important:** Only letters, digits, and the characters `-._~` are safe in this password. The application workloads construct their broker connection URL by concatenating `amqp://` + username + `:` + password + `@` + host, with no escaping. A password containing `@`, `/`, `%`, or other URL metacharacters will be misparsed by the AMQP client and result in authentication failures.

### 2. The bundled broker now seeds its user from plaintext instead of a hash

**What changed:**

The `rabbitmq.loadDefinition.passwordHash` value and the template logic that injected it into the broker's boot definitions were removed. The bundled broker's `load_definitions.json` now declares the application user with a plaintext `password` field instead of `password_hash` + `hashing_algorithm`.

**Before (v4.3.11) — templates/manager/secrets_rabbitmq_definitions.yaml:**

```yaml
{{- $hash := (default dict .Values.rabbitmq.loadDefinition).passwordHash }}
{{- $_ := set $defs "users" (list (dict "name" $user "password_hash" $hash "hashing_algorithm" "rabbit_password_hashing_sha256" "tags" "administrator")) }}
```

**After (v4.3.12) — templates/manager/secrets_rabbitmq_definitions.yaml:**

```yaml
{{- $pass := toString .Values.secrets.RABBITMQ_DEFAULT_PASS }}
{{- $_ := set $defs "users" (list (dict "name" $user "password" $pass "tags" "management")) }}
```

The definitions Secret is still emitted at the same name (`<release-name>-bootstrap-rabbitmq-definitions`), mounted at `/etc/rabbitmq/definitions`, and imported by the broker at boot via `management.load_definitions`. What changed is the structure of the `users` array inside that JSON: RabbitMQ accepts either a pre-hashed `password_hash` or a plaintext `password`, and the chart now uses the latter.

**Why this matters:**

A plaintext password in the definitions allows Helm to template the user declaration from the same `secrets.RABBITMQ_DEFAULT_PASS` value the workloads use, with no intermediate hash that Helm cannot compute. The password and the broker's expected credential are now guaranteed to match because they come from the same source. This removes the render-time guard that refused custom bundled credentials in v4.3.11 (the `reporter.rabbitmqLoadDefinitionConsistent` helper and its associated `fail` calls were deleted).

The user's `tags` also changed from `"administrator"` to `"management"`. The `administrator` tag grants full management API access and is not required for the application's broker operations (publish, consume, declare topology). The `management` tag allows the user to log in to the management UI for its own vhost and see its own connections, which is sufficient for operational visibility. The user's AMQP permissions (`configure`/`write`/`read` on vhost `/`) are unchanged.

**What operators need to do:**

Nothing beyond setting the password (item 1). The change is internal to the chart's templating and does not introduce new values keys or require configuration changes.

> **Note:** The definitions Secret is regenerated on every `helm upgrade`, and the broker re-imports it on every pod restart. If you upgrade the chart with a new password but do not restart the broker pod, the broker continues to authenticate against its **old** password (the one it imported at its last boot) until the pod restarts. The error message in item 1 and item 3 includes the restart command; see [Migration Steps](#migration-steps) for the full sequence.

### 3. Weak passwords are refused at render time

**What changed:**

When `rabbitmq.enabled` is `true`, the chart now fails the render if `secrets.RABBITMQ_DEFAULT_PASS` is set to any of the following strings:

- `reporter123` (the fixed dev credential shipped in v4.3.11 and earlier)
- `Lerian@123` (a placeholder printed in some values-template examples)
- `CHANGE_ME` (a common placeholder)

The check is case-sensitive and matches the exact string. A password of `Reporter123` or `reporter1234` is not refused.

**Error message when a weak password is detected:**

```text
Error: execution error at (reporter/templates/manager/secrets_rabbitmq_definitions.yaml): rabbitmq.enabled: secrets.RABBITMQ_DEFAULT_PASS is reporter123, a password printed in this chart (a default of earlier versions, or the values-template placeholder). Set another and upgrade, then restart the broker, which keeps its old password until its pod restarts: kubectl -n <namespace> rollout restart statefulset/<release-name>-rabbitmq
```

**Why this matters:**

The three refused strings are either documented defaults from prior chart versions or placeholder text that appears in values examples. Refusing them at render time prevents an operator from accidentally deploying the bundled broker with a publicly known or obviously temporary credential. The check runs only when the bundled broker is enabled; it does not apply to external-broker configurations (`rabbitmq.enabled=false`), where the credential is provisioned outside the chart.

**What operators need to do:**

If your `values.yaml` or `--set` overrides currently set `RABBITMQ_DEFAULT_PASS` to one of the three refused strings, change it to a different password before upgrading. The render will fail otherwise.

## Configuration Changes

| Setting | v4.3.11 | v4.3.12 | Notes |
|---------|---------|---------|-------|
| `secrets.RABBITMQ_DEFAULT_PASS` | `"reporter123"` | `""` | Now required (empty fails render); weak passwords refused when `rabbitmq.enabled` |
| `rabbitmq.loadDefinition` | object with `passwordHash` key | **removed** | The bundled broker seeds from plaintext; no hash is needed |
| `rabbitmq.loadDefinition.passwordHash` | `"MUFZJnvzY2bazWkfRR7p0lSPa0TNRf/ievZm4fG46s/5lu7G"` | **removed** | Computed hash is no longer used |

No new values keys were added. The `rabbitmq.loadDefinition` block and its `passwordHash` child were removed entirely; setting them in v4.3.12 has no effect (the chart's schema allows unknown keys, so they are accepted and ignored).

## Who is affected

**All installations must set `secrets.RABBITMQ_DEFAULT_PASS` to a non-empty value.** The render fails otherwise, regardless of whether the bundled broker is enabled.

**Installations using the bundled RabbitMQ broker (`rabbitmq.enabled: true`) must also:**

1. Change the password from `reporter123` if it was left at the v4.3.11 default
2. Restart the broker pod after upgrading, so it imports the new password

**Installations using an external broker (`rabbitmq.enabled: false`) are not affected by the broker-seeding changes** (items 2 and 3), but they must still set the password to a non-empty value to satisfy the render-time check. If the password was already set to a custom value in v4.3.11, no change is required.

**Measured — Lerian-operated tiers:** Across the 12 reporter tier values files in the Lerian gitops repositories, `rabbitmq.enabled` does not appear in any of them, so the bundled broker runs in **0 of 12** tiers (the chart default is `false`). All 12 tiers use an external broker and are unaffected by the broker-seeding changes. However, **2 of 12** tiers do not set `secrets.RABBITMQ_DEFAULT_PASS` explicitly and rely on the chart default; those two tiers will fail the render in v4.3.12 until the password is set.

## Migration Steps

### For all installations

1. Set `secrets.RABBITMQ_DEFAULT_PASS` in your `values.yaml` or via `--set` if it is not already set:

   ```yaml
   secrets:
     RABBITMQ_DEFAULT_PASS: "your-custom-password-here"
   ```

   The password must not be empty, and if you enable the bundled broker it must not be `reporter123`, `Lerian@123`, or `CHANGE_ME`.

2. Preview the changes with the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

3. Run the upgrade command.

### Additional steps when using the bundled broker (`rabbitmq.enabled: true`)

4. After the upgrade completes, restart the RabbitMQ StatefulSet so it imports the new password:

   ```bash
   kubectl -n <namespace> rollout restart statefulset/<release-name>-rabbitmq
   ```

   Wait for the broker pod to become ready:

   ```bash
   kubectl -n <namespace> rollout status statefulset/<release-name>-rabbitmq
   ```

5. Verify the manager and worker pods can authenticate to the broker with the new password:

   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50 | grep -i "amqp\|rabbit\|connection"
   kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50 | grep -i "amqp\|rabbit\|connection"
   ```

   Look for successful connection messages. Authentication failures will appear as `403 ACCESS_REFUSED` or similar.

> **Warning:** If you upgrade the chart but do not restart the broker pod, the broker continues to use the password it imported at its last boot. The manager and worker pods will restart with the new password (from the upgraded `reporter-manager` and `reporter-worker` Secrets) and will fail to authenticate until the broker is restarted.

### If you previously overrode `rabbitmq.loadDefinition.passwordHash`

6. Remove the `rabbitmq.loadDefinition` block from your `values.yaml`. It is no longer used and has no effect in v4.3.12:

   **Before (v4.3.11):**

   ```yaml
   rabbitmq:
     enabled: true
     loadDefinition:
       passwordHash: "your-custom-hash"
   ```

   **After (v4.3.12):**

   ```yaml
   rabbitmq:
     enabled: true
   ```

   The password is now sourced from `secrets.RABBITMQ_DEFAULT_PASS` only.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.12 -n reporter
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.12 -n reporter
```
