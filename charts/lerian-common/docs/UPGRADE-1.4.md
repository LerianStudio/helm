# Helm Upgrade from v1.3.4 to v1.4.0

## Topics ToC

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Improved SASL Configuration Validation](#1-improved-sasl-configuration-validation)
  - [2. Stricter Boolean Parsing for TLS and Plaintext SASL](#2-stricter-boolean-parsing-for-tls-and-plaintext-sasl)
  - [3. Enhanced Secret Validation Consistency](#3-enhanced-secret-validation-consistency)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

The `lerian-common` chart v1.4.0 introduces **stricter validation and normalization** for streaming (Kafka/RedPanda) SASL configuration. This is a **minor release** that improves robustness and error messages without breaking valid configurations.

**What changed:**

- SASL mechanism and username validation now normalizes whitespace and case before checking values
- Boolean parsing for `STREAMING_TLS_ENABLED` and `STREAMING_SASL_ALLOW_PLAINTEXT` now matches the runtime's exact `strconv.ParseBool` behavior
- Nil/null YAML values for SASL mechanism are now explicitly handled to prevent rendering literal `<nil>` strings
- Secret validation for SASL credentials now uses the same normalization as ConfigMap validation

**Who is affected:**

- Operators with streaming SASL enabled (`global.streaming.saslMechanism` set)
- Operators using non-standard boolean spellings (e.g. `TrUe`, ` true `) for TLS or plaintext SASL flags
- Operators with whitespace-only or null SASL configuration values

**Backward compatibility:**

All **valid** configurations from v1.3.4 continue to work unchanged. The changes only affect:

1. **Invalid configurations** that would have crashed at runtime (now fail at render time with clearer errors)
2. **Edge-case spellings** (e.g. `TrUe` for booleans) that would have been rejected by the runtime (now rejected at render time)

If your existing deployment is running successfully, upgrading to v1.4.0 will not change the rendered output.

## Features

### 1. Improved SASL Configuration Validation

The `lerian-common.streaming.env` and `lerian-common.streaming.secret` helpers now normalize SASL mechanism values before validation, matching the behavior of the `lib-streaming` runtime library.

**What changed:**

| Aspect | v1.3.4 | v1.4.0 |
|--------|---------|---------|
| Mechanism normalization | Raw value checked against allowlist | Trimmed, uppercased, then checked |
| Case sensitivity | Case-sensitive (`plain` rejected) | Case-insensitive (`plain` → `PLAIN` accepted) |
| Whitespace handling | Leading/trailing spaces rejected | Trimmed before validation |
| Null/nil handling | Rendered as literal `<nil>` string | Coerced to `""` (SASL disabled) |
| Non-string types | Silently coerced to `""` by `default` | Preserved, then rejected with clear error |

**Why it matters:**

In v1.3.4, the following valid runtime configurations were incorrectly rejected at render time:

```yaml
global:
  streaming:
    saslMechanism: "scram-sha-256"  # Rejected (lowercase)
    saslUsername: "user"
```

```yaml
global:
  streaming:
    saslMechanism: "  PLAIN  "  # Rejected (whitespace)
    saslUsername: "user"
```

In v1.4.0, these configurations are **accepted** because the helper now normalizes the mechanism (trim + uppercase) before checking the allowlist, matching what `lib-streaming` does at runtime.

**Operational impact:**

- **Valid configurations:** No change. Mechanisms like `PLAIN`, `SCRAM-SHA-256`, `SCRAM-SHA-512` continue to work.
- **Case-insensitive input:** Now accepted. `plain`, `scram-sha-256`, `Scram-Sha-512` are normalized to uppercase and validated.
- **Whitespace-padded input:** Now accepted. `"  PLAIN  "` is trimmed to `PLAIN`.
- **Null/nil values:** Now handled correctly. A YAML `null` for `saslMechanism` disables SASL (renders as `""`) instead of crashing with `<nil>`.
- **Invalid types:** Now rejected with a clear error. Setting `saslMechanism: false` or `saslMechanism: 0` will fail at render time (instead of silently disabling SASL, which would be an auth downgrade).

**Error message improvements:**

**Before (v1.3.4):**

```
[lerian-common] Unsupported STREAMING_SASL_MECHANISM "scram-sha-256" — lib-streaming accepts only PLAIN, SCRAM-SHA-256, SCRAM-SHA-512.
```

**After (v1.4.0):**

```
[lerian-common] Unsupported STREAMING_SASL_MECHANISM "scram-sha-256" — lib-streaming accepts only PLAIN, SCRAM-SHA-256, SCRAM-SHA-512 (case-insensitive).
```

The error message now clarifies that the mechanism is case-insensitive, and the validation happens **after** normalization (so a lowercase input that is valid will not trigger this error).

### 2. Stricter Boolean Parsing for TLS and Plaintext SASL

The `lerian-common.streaming.env` helper now validates `STREAMING_TLS_ENABLED` and `STREAMING_SASL_ALLOW_PLAINTEXT` using the **exact** `strconv.ParseBool` logic that the runtime uses.

**What changed:**

| Boolean value | v1.3.4 behavior | v1.4.0 behavior |
|---------------|-----------------|-----------------|
| `true`, `TRUE`, `True`, `t`, `T`, `1` | Accepted as `true` | Accepted as `true` |
| `false`, `FALSE`, `False`, `f`, `F`, `0` | Accepted as `false` | Accepted as `false` |
| `TrUe`, `FaLsE` (mixed case) | Accepted (via `lower()`) | **Rejected** (does not match `strconv.ParseBool`) |
| `" true "` (whitespace-padded) | Accepted (via `trim()`) | **Rejected** (does not match `strconv.ParseBool`) |
| Empty string `""` | Treated as `false` | Treated as `false` |

**Why it matters:**

The runtime's `GetenvBoolOrDefault` uses Go's `strconv.ParseBool`, which accepts **only** the exact spellings listed above (no trimming, no case normalization beyond the documented set). In v1.3.4, the Helm template used `lower()` and `trim()`, which accepted values like `"TrUe"` or `" true "` at render time — but these would **fail** at runtime, causing the application to crash during bootstrap.

In v1.4.0, the template rejects these invalid spellings at render time with a clear error, preventing a deployment that would crash.

**Operational impact:**

- **Standard boolean values:** No change. `true`, `false`, `1`, `0`, `t`, `f` (and their documented case variants) continue to work.
- **Non-standard spellings:** Now rejected at render time. If you have `STREAMING_TLS_ENABLED: "TrUe"` or `STREAMING_SASL_ALLOW_PLAINTEXT: " true "`, the `helm upgrade` will fail with:

```
[lerian-common] SASL requires TLS: mechanism SCRAM-SHA-256 is set but STREAMING_TLS_ENABLED is not true.
  set:     STREAMING_TLS_ENABLED=true (recommended), or opt into plaintext SASL with STREAMING_SASL_ALLOW_PLAINTEXT=true.
```

**Migration:** If your deployment is currently running, your boolean values are already valid. If `helm upgrade` fails with the above error, check your `values.yaml` for non-standard boolean spellings and correct them:

**Before (v1.3.4 — accepted but would crash at runtime):**

```yaml
global:
  streaming:
    tlsEnabled: "TrUe"
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "user"
```

**After (v1.4.0 — required):**

```yaml
global:
  streaming:
    tlsEnabled: true  # or "true", "TRUE", "1", "t", "T"
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "user"
```

### 3. Enhanced Secret Validation Consistency

The `lerian-common.streaming.secret` helper now normalizes SASL mechanism and username values **before** validating that credentials are required, ensuring consistency with the ConfigMap validation in `lerian-common.streaming.env`.

**What changed:**

| Aspect | v1.3.4 | v1.4.0 |
|--------|---------|---------|
| Mechanism check | Raw value (truthy if non-empty) | Normalized (`trim(toString(x \| default ""))`) |
| Username check | Raw value (truthy if non-empty) | Normalized (`trim(toString(x \| default ""))`) |
| Whitespace-only values | Treated as "set" (credentials required) | Treated as "unset" (credentials not required) |

**Why it matters:**

In v1.3.4, the following configuration would **pass** Secret validation (because `saslMechanism: "   "` is truthy) but **fail** ConfigMap validation (because the trimmed mechanism is empty):

```yaml
global:
  streaming:
    saslMechanism: "   "  # Whitespace-only
    saslUsername: "user"
```

This inconsistency could cause confusing errors where the Secret is rendered but the ConfigMap validation fails.

In v1.4.0, both helpers normalize the mechanism and username identically (`trim(toString(x | default ""))`), so a whitespace-only mechanism is treated as "SASL disabled" in **both** the ConfigMap and the Secret.

**Operational impact:**

- **Valid configurations:** No change. If your mechanism and username are non-empty strings, validation behavior is identical.
- **Whitespace-only values:** Now handled consistently. A whitespace-only mechanism or username will **not** require credentials in the Secret (because SASL is considered disabled).
- **Null/nil values:** Now handled consistently. A YAML `null` for `saslMechanism` or `saslUsername` disables SASL in both helpers.

**Error message improvements:**

The Secret validation error messages now use `%v` (instead of `%s`) for the mechanism, so non-string types (e.g. `saslMechanism: false`) are printed as-is (e.g. `false`) instead of rendering as `%!s(bool=false)`.

**Before (v1.3.4):**

```
[lerian-common] Value required but empty: STREAMING_SASL_USERNAME
  a SASL mechanism (%!s(bool=false)) is set, which requires both a username and a password.
```

**After (v1.4.0):**

```
[lerian-common] Value required but empty: STREAMING_SASL_USERNAME
  a SASL mechanism (false) is set, which requires both a username and a password.
```

## Migration Steps

### For Operators with Valid Configurations

If your existing deployment is running successfully with SASL enabled, **no action is required**. The v1.4.0 validation changes only affect invalid configurations that would have crashed at runtime.

**Verification:**

1. Check your current streaming configuration:

```bash
helm get values <release-name> -n <namespace> | grep -A 10 "streaming:"
```

2. Verify that your SASL mechanism is one of the supported values (case-insensitive):
   - `PLAIN` (or `plain`, `Plain`)
   - `SCRAM-SHA-256` (or `scram-sha-256`, `Scram-Sha-256`)
   - `SCRAM-SHA-512` (or `scram-sha-512`, `Scram-Sha-512`)

3. Verify that your boolean flags use standard spellings:
   - `tlsEnabled: true` (or `"true"`, `"TRUE"`, `"1"`, `"t"`, `"T"`)
   - `saslAllowPlaintext: false` (or `"false"`, `"FALSE"`, `"0"`, `"f"`, `"F"`)

4. Upgrade to v1.4.0:

```bash
helm upgrade <release-name> oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.4.0 -n <namespace>
```

### For Operators with Non-Standard Boolean Spellings

If you have used non-standard boolean spellings (e.g. `TrUe`, ` true `) in your `values.yaml`, the upgrade will fail at render time. Follow these steps to correct the configuration:

1. **Identify non-standard boolean values** in your `values.yaml`:

```bash
grep -E "(tlsEnabled|saslAllowPlaintext):" values.yaml
```

2. **Correct the spellings** to use standard `strconv.ParseBool` values:

**Before:**

```yaml
global:
  streaming:
    tlsEnabled: "TrUe"
    saslAllowPlaintext: " false "
```

**After:**

```yaml
global:
  streaming:
    tlsEnabled: true
    saslAllowPlaintext: false
```

3. **Test the corrected configuration** with `helm template`:

```bash
helm template <release-name> <chart-path> --values values.yaml --debug
```

4. **Upgrade** once the template renders successfully:

```bash
helm upgrade <release-name> oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.4.0 -n <namespace> --values values.yaml
```

### For Operators with Whitespace or Null SASL Values

If you have whitespace-only or null values for `saslMechanism` or `saslUsername`, the v1.4.0 normalization will treat them as "SASL disabled" (empty string). If this is intentional (you want SASL off), no action is required. If you intended to enable SASL, correct the values:

**Before (whitespace-only mechanism — SASL disabled):**

```yaml
global:
  streaming:
    saslMechanism: "   "
    saslUsername: "user"
```

**After (SASL enabled):**

```yaml
global:
  streaming:
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "user"
```

**Before (null mechanism — SASL disabled):**

```yaml
global:
  streaming:
    saslMechanism: null
    saslUsername: "user"
```

**After (SASL enabled):**

```yaml
global:
  streaming:
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "user"
```

### For Chart Maintainers

If you maintain a product chart that consumes `lerian-common`, update the dependency version in your `Chart.yaml`:

**Before:**

```yaml
dependencies:
  - name: lerian-common
    version: 1.3.4
    repository: oci://registry-1.docker.io/lerianstudio
```

**After:**

```yaml
dependencies:
  - name: lerian-common
    version: 1.4.0
    repository: oci://registry-1.docker.io/lerianstudio
```

Then update dependencies:

```bash
helm dependency update
```

Test that your chart renders correctly with the new validation:

```bash
helm template <chart-name> . --values test-values.yaml --debug
```

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.4.0 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Important:** Since `lerian-common` is a library chart, `helm diff` will show no resource changes (library charts render nothing). To preview the impact of upgrading to v1.4.0, run `helm diff` on the **product charts** that consume it after updating their `lerian-common` dependency version.

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.4.0 -n lerian-common
```

> **Note:** Since `lerian-common` is a library chart, you typically do **not** install or upgrade it directly. Instead, update the dependency version in your umbrella or product chart's `Chart.yaml` to `1.4.0` and run `helm dependency update`, then upgrade the consuming chart.
