# Helm Upgrade from v1.3.3 to v1.3.4

## Topics ToC

- **[Fixes](#fixes)**
  - [1. SASL Contract Validation](#1-sasl-contract-validation)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. SASL Contract Validation

The `lerian-common.streaming.env` helper now validates the SASL configuration contract at template render time to prevent runtime failures when lib-streaming attempts to bootstrap with incomplete or invalid SASL settings.

#### What changed

The `_streaming.tpl` template now enforces three validation rules when `STREAMING_SASL_MECHANISM` is set:

1. **Mechanism must be supported:** Only `PLAIN`, `SCRAM-SHA-256`, and `SCRAM-SHA-512` are accepted
2. **Username is required:** `STREAMING_SASL_USERNAME` must be set when a SASL mechanism is configured
3. **TLS is required (unless explicitly opted out):** `STREAMING_TLS_ENABLED` must be `true`, or `STREAMING_SASL_ALLOW_PLAINTEXT` must be `true`

#### Why it matters

**Before (v1.3.3):**

If an operator configured SASL with an unsupported mechanism, missing username, or without TLS, the chart would render successfully but the application would fail at runtime when lib-streaming attempted to connect to the broker. This resulted in cryptic bootstrap errors that were difficult to diagnose.

**After (v1.3.4):**

The chart fails fast during `helm template`, `helm install`, or `helm upgrade` with a clear error message explaining exactly what is missing or misconfigured. This shifts the validation from runtime to deploy-time, making misconfigurations immediately visible to operators.

#### Operational impact

> **Important:** This is a **validation-only change**. If your existing SASL configuration is valid, you will see no difference in behavior. If your configuration is invalid, the chart will now fail to render instead of deploying a broken configuration.

**No action required if:**

- You do not use SASL (`STREAMING_SASL_MECHANISM` is empty or unset)
- Your SASL configuration is already valid (supported mechanism, username set, TLS enabled or plaintext explicitly allowed)

**Action required if:**

Your existing configuration has any of these issues:

1. **Unsupported SASL mechanism:** You are using a mechanism other than `PLAIN`, `SCRAM-SHA-256`, or `SCRAM-SHA-512`
2. **Missing username:** You have set `STREAMING_SASL_MECHANISM` but not `STREAMING_SASL_USERNAME`
3. **Missing TLS:** You have set `STREAMING_SASL_MECHANISM` but `STREAMING_TLS_ENABLED` is `false` and `STREAMING_SASL_ALLOW_PLAINTEXT` is not `true`

#### Error messages

When validation fails, you will see one of these error messages during `helm upgrade`:

**Unsupported mechanism:**

```
Error: template: lerian-common/templates/_streaming.tpl:75:4: executing "lerian-common.streaming.env" at <fail (printf "\n[lerian-common] Unsupported STREAMING_SASL_MECHANISM %q — lib-streaming accepts only PLAIN, SCRAM-SHA-256, SCRAM-SHA-512.\n" $saslMechanism)>: error calling fail:
[lerian-common] Unsupported STREAMING_SASL_MECHANISM "SCRAM-SHA-1" — lib-streaming accepts only PLAIN, SCRAM-SHA-256, SCRAM-SHA-512.
```

**Missing username:**

```
Error: template: lerian-common/templates/_streaming.tpl:78:4: executing "lerian-common.streaming.env" at <fail (printf "\n[lerian-common] Value required but empty: STREAMING_SASL_USERNAME\n  a SASL mechanism (%s) is set, which requires a username (and a password).\n  set:     configmap.STREAMING_SASL_USERNAME (or global.streaming.saslUsername)\n" $saslMechanism)>: error calling fail:
[lerian-common] Value required but empty: STREAMING_SASL_USERNAME
  a SASL mechanism (SCRAM-SHA-256) is set, which requires a username (and a password).
  set:     configmap.STREAMING_SASL_USERNAME (or global.streaming.saslUsername)
```

**Missing TLS:**

```
Error: template: lerian-common/templates/_streaming.tpl:81:4: executing "lerian-common.streaming.env" at <fail (printf "\n[lerian-common] SASL requires TLS: mechanism %s is set but STREAMING_TLS_ENABLED is not true.\n  set:     STREAMING_TLS_ENABLED=true (recommended), or opt into plaintext SASL with STREAMING_SASL_ALLOW_PLAINTEXT=true.\n" $saslMechanism)>: error calling fail:
[lerian-common] SASL requires TLS: mechanism SCRAM-SHA-256 is set but STREAMING_TLS_ENABLED is not true.
  set:     STREAMING_TLS_ENABLED=true (recommended), or opt into plaintext SASL with STREAMING_SASL_ALLOW_PLAINTEXT=true.
```

#### Migration steps

If your upgrade fails with one of the validation errors above, follow these steps to fix your configuration:

**Step 1: Identify the validation failure**

Read the error message to determine which validation rule failed (unsupported mechanism, missing username, or missing TLS).

**Step 2: Fix the configuration**

Choose the appropriate fix based on the validation failure:

##### Fix 1: Unsupported SASL mechanism

If you are using an unsupported mechanism (e.g. `SCRAM-SHA-1`, `GSSAPI`), update your configuration to use one of the supported mechanisms.

**Umbrella `values.yaml` (global configuration):**

```yaml
global:
  streaming:
    saslMechanism: "SCRAM-SHA-256"  # or "SCRAM-SHA-512" or "PLAIN"
```

**Product chart `values.yaml` (component-level override):**

```yaml
myapp:
  configmap:
    STREAMING_SASL_MECHANISM: "SCRAM-SHA-256"  # or "SCRAM-SHA-512" or "PLAIN"
```

##### Fix 2: Missing SASL username

If you have set a SASL mechanism but not a username, add the username to your configuration.

**Umbrella `values.yaml` (global configuration):**

```yaml
global:
  streaming:
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "lerian-user"
```

**Product chart `values.yaml` (component-level override):**

```yaml
myapp:
  configmap:
    STREAMING_SASL_MECHANISM: "SCRAM-SHA-256"
    STREAMING_SASL_USERNAME: "lerian-user"
```

> **Note:** The SASL password (`STREAMING_SASL_PASSWORD`) is a secret and must be set in the component's `.secrets` block, never in `global.streaming` or `configmap`.

##### Fix 3: Missing TLS

If you have set a SASL mechanism but TLS is disabled, you have two options:

**Option 1: Enable TLS (recommended)**

Enable TLS for broker connections to secure SASL credentials in transit.

**Umbrella `values.yaml` (global configuration):**

```yaml
global:
  streaming:
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "lerian-user"
    tlsEnabled: true
```

**Product chart `values.yaml` (component-level override):**

```yaml
myapp:
  configmap:
    STREAMING_SASL_MECHANISM: "SCRAM-SHA-256"
    STREAMING_SASL_USERNAME: "lerian-user"
    STREAMING_TLS_ENABLED: "true"
```

**Option 2: Opt into plaintext SASL (not recommended)**

If your broker does not support TLS and you accept the security risk of transmitting SASL credentials in plaintext, explicitly opt in by setting `STREAMING_SASL_ALLOW_PLAINTEXT`.

> **Warning:** Plaintext SASL transmits credentials unencrypted over the network. This option should only be used in development environments or when the network is otherwise secured (e.g. private VPC, VPN).

**Product chart `values.yaml` (component-level override):**

```yaml
myapp:
  configmap:
    STREAMING_SASL_MECHANISM: "SCRAM-SHA-256"
    STREAMING_SASL_USERNAME: "lerian-user"
    STREAMING_TLS_ENABLED: "false"
    STREAMING_SASL_ALLOW_PLAINTEXT: "true"
```

> **Note:** `STREAMING_SASL_ALLOW_PLAINTEXT` is a component-level setting and cannot be set globally. Each product chart that uses plaintext SASL must set this flag explicitly.

**Step 3: Retry the upgrade**

After fixing the configuration, retry the upgrade:

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.4 -n lerian-common --values values.yaml
```

#### Configuration reference

The validation logic checks these configuration fields:

| Field | Source | Description |
|-------|--------|-------------|
| `STREAMING_SASL_MECHANISM` | `global.streaming.saslMechanism` or `configmap.STREAMING_SASL_MECHANISM` | SASL mechanism (must be `PLAIN`, `SCRAM-SHA-256`, or `SCRAM-SHA-512`) |
| `STREAMING_SASL_USERNAME` | `global.streaming.saslUsername` or `configmap.STREAMING_SASL_USERNAME` | SASL username (required when mechanism is set) |
| `STREAMING_TLS_ENABLED` | `global.streaming.tlsEnabled` or `configmap.STREAMING_TLS_ENABLED` | Enable TLS for broker connections (required when mechanism is set, unless plaintext is allowed) |
| `STREAMING_SASL_ALLOW_PLAINTEXT` | `configmap.STREAMING_SASL_ALLOW_PLAINTEXT` | Opt into plaintext SASL (allows SASL without TLS; component-level only) |

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.4 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.4 -n lerian-common
```
