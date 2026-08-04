# Helm Upgrade from v1.3.2 to v1.3.3

## Topics ToC

- **[Fixes](#fixes)**
  - [1. Streaming SASL Username Validation](#1-streaming-sasl-username-validation)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Fixes

### 1. Streaming SASL Username Validation

The `lerian-common.streaming.secret` helper now validates that `STREAMING_SASL_USERNAME` is set when a SASL mechanism is configured, preventing boot-time crashes caused by incomplete SASL credentials.

#### What changed

The streaming secret helper now enforces that **both** `STREAMING_SASL_USERNAME` and `STREAMING_SASL_PASSWORD` are present when `STREAMING_SASL_MECHANISM` is set. Previously, the helper only validated the password, which allowed configurations with a mechanism but no username to pass Helm validation and fail at application boot.

The helper now resolves `STREAMING_SASL_USERNAME` with the same precedence as the ConfigMap (component-level `configmap.STREAMING_SASL_USERNAME` > `global.streaming.saslUsername`), ensuring that ConfigMap-only usernames are validated correctly.

| Validation | v1.3.2 | v1.3.3 |
|------------|---------|---------|
| SASL password required when mechanism is set | ✅ Yes | ✅ Yes |
| SASL username required when mechanism is set | ❌ No | ✅ Yes |
| Username resolved with configmap-over-global precedence | ❌ No | ✅ Yes |

#### Why it matters

**lib-streaming** (the application library that consumes these environment variables) rejects a SASL mechanism without both username and password, causing the application to crash at boot. Without this validation, operators could deploy a configuration that passes `helm upgrade` but fails immediately when the pod starts.

This fix moves the failure point from **runtime** (pod crash loop) to **render time** (Helm validation error), giving operators immediate feedback during deployment.

#### Operational impact

**For operators with valid configurations:** No action required. If you already set both `STREAMING_SASL_USERNAME` and `STREAMING_SASL_PASSWORD` when using SASL, your configuration is valid and will continue to work.

**For operators with incomplete SASL configurations:** If you set `STREAMING_SASL_MECHANISM` but omitted `STREAMING_SASL_USERNAME`, Helm will now fail with a clear error message during `helm upgrade` or `helm template`:

```
[lerian-common] Value required but empty: STREAMING_SASL_USERNAME
  a SASL mechanism (SCRAM-SHA-256) is set, which requires both a username and a password.
  set:     configmap.STREAMING_SASL_USERNAME (or global.streaming.saslUsername)
```

#### Configuration requirements

When `STREAMING_SASL_MECHANISM` is set (either via `global.streaming.saslMechanism` or component-level `configmap.STREAMING_SASL_MECHANISM`), you **must** set:

1. **STREAMING_SASL_USERNAME** (ConfigMap value, not a secret):
   - Via `global.streaming.saslUsername` (shared across all components), OR
   - Via component-level `configmap.STREAMING_SASL_USERNAME` (per-component override)

2. **STREAMING_SASL_PASSWORD** (Secret value):
   - Via component-level `secrets.STREAMING_SASL_PASSWORD`

**Example configuration (umbrella `values.yaml`):**

```yaml
global:
  streaming:
    brokers: "redpanda.prod.example.com:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "lerian-user"  # ← Required when saslMechanism is set

ledger:
  secrets:
    STREAMING_SASL_PASSWORD: "vault:secret/data/streaming#password"  # ← Required when saslMechanism is set
```

**Example configuration (component-level override):**

```yaml
global:
  streaming:
    brokers: "redpanda.prod.example.com:9092"
    tlsEnabled: true

ledger:
  configmap:
    STREAMING_SASL_MECHANISM: "SCRAM-SHA-256"
    STREAMING_SASL_USERNAME: "ledger-user"  # ← Required when mechanism is set at component level
  secrets:
    STREAMING_SASL_PASSWORD: "vault:secret/data/ledger-streaming#password"
```

> **Important:** `STREAMING_SASL_USERNAME` is a **ConfigMap value** (not a secret). It is resolved with the same precedence as other streaming ConfigMap values: component-level `configmap.STREAMING_SASL_USERNAME` takes precedence over `global.streaming.saslUsername`.

> **Note:** If you set `STREAMING_SASL_MECHANISM` to an empty string explicitly (e.g., to override a global mechanism at the component level), the validation will not require username or password. Only non-empty mechanism values trigger the validation.

#### Template changes

**Before (v1.3.2):**

The helper accepted `saslMechanism` as an input and validated only the password:

```yaml
{{- with (include "lerian-common.streaming.secret" (dict
      "context" . "secrets" .Values.ledger.secrets
      "secretName" (include "midaz.ledger.fullname" .)
      "valuesPrefix" "ledger.secrets." "mode" "data"
      "enabled" true "useExistingSecret" .Values.ledger.useExistingSecret
      "saslMechanism" (dig "streaming" "saslMechanism" "" (.Values.global | default dict)))) }}
{{- . | nindent 2 }}
{{- end }}
```

**After (v1.3.3):**

The helper now accepts both `saslMechanism` and `saslUsername` as inputs, resolving the username with the same precedence as the ConfigMap:

```yaml
{{- $saslMech := (((.Values.global | default dict).streaming | default dict).saslMechanism | default "") }}
{{- if hasKey .Values.ledger.configmap "STREAMING_SASL_MECHANISM" }}{{- $saslMech = index .Values.ledger.configmap "STREAMING_SASL_MECHANISM" }}{{- end }}
{{- $saslUser := (((.Values.global | default dict).streaming | default dict).saslUsername | default "") }}
{{- if hasKey .Values.ledger.configmap "STREAMING_SASL_USERNAME" }}{{- $saslUser = index .Values.ledger.configmap "STREAMING_SASL_USERNAME" }}{{- end }}
{{- with (include "lerian-common.streaming.secret" (dict
      "context" . "secrets" .Values.ledger.secrets
      "secretName" (include "midaz.ledger.fullname" .)
      "valuesPrefix" "ledger.secrets." "mode" "data"
      "enabled" true "useExistingSecret" .Values.ledger.useExistingSecret
      "saslMechanism" $saslMech "saslUsername" $saslUser)) }}
{{- . | nindent 2 }}
{{- end }}
```

**For product chart maintainers:** If your chart calls `lerian-common.streaming.secret`, you must update the call site to resolve and pass `saslUsername` using the same precedence logic shown above. The helper will fail with a clear error if `saslMechanism` is set but `saslUsername` is not provided.

## Migration Steps

### For Operators

1. **Review your streaming configuration.** If you use SASL authentication (`STREAMING_SASL_MECHANISM` is set), ensure you have set `STREAMING_SASL_USERNAME`:

```bash
# Check your umbrella values.yaml or component values
grep -A5 "streaming:" values.yaml
```

2. **If `STREAMING_SASL_USERNAME` is missing,** add it to your configuration:

**Option 1: Set globally (shared across all components):**

```yaml
global:
  streaming:
    saslMechanism: "SCRAM-SHA-256"
    saslUsername: "lerian-user"  # ← Add this
```

**Option 2: Set per component:**

```yaml
ledger:
  configmap:
    STREAMING_SASL_MECHANISM: "SCRAM-SHA-256"
    STREAMING_SASL_USERNAME: "ledger-user"  # ← Add this
```

3. **Verify the configuration** by running a dry-run upgrade:

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm \
  --version 1.3.3 \
  --namespace lerian-common \
  --values values.yaml \
  --dry-run
```

4. **If the dry-run succeeds,** proceed with the upgrade (see [Command to upgrade](#command-to-upgrade)).

### For Product Chart Maintainers

If your product chart calls `lerian-common.streaming.secret`, update the call site to resolve and pass `saslUsername`:

1. **Before the helper call,** resolve `saslMechanism` and `saslUsername` with configmap-over-global precedence:

```yaml
{{- $saslMech := (((.Values.global | default dict).streaming | default dict).saslMechanism | default "") }}
{{- if hasKey .Values.myapp.configmap "STREAMING_SASL_MECHANISM" }}{{- $saslMech = index .Values.myapp.configmap "STREAMING_SASL_MECHANISM" }}{{- end }}
{{- $saslUser := (((.Values.global | default dict).streaming | default dict).saslUsername | default "") }}
{{- if hasKey .Values.myapp.configmap "STREAMING_SASL_USERNAME" }}{{- $saslUser = index .Values.myapp.configmap "STREAMING_SASL_USERNAME" }}{{- end }}
```

2. **Pass both values to the helper:**

```yaml
{{- with (include "lerian-common.streaming.secret" (dict
      "context" . "secrets" .Values.myapp.secrets
      "secretName" (include "myapp.fullname" .)
      "valuesPrefix" "myapp.secrets." "mode" "data"
      "enabled" true "useExistingSecret" .Values.myapp.useExistingSecret
      "saslMechanism" $saslMech "saslUsername" $saslUser)) }}
{{- . | nindent 2 }}
{{- end }}
```

3. **Test the change** by rendering the chart with a SASL configuration:

```bash
helm template myapp . --values test-values-sasl.yaml
```

> **Note:** The helper will fail with a descriptive error if `saslMechanism` is set but `saslUsername` is empty, preventing invalid configurations from being deployed.

## Preview changes before upgrading

```bash
helm diff upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.3 -n lerian-common
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade lerian-common oci://registry-1.docker.io/lerianstudio/lerian-common-helm --version 1.3.3 -n lerian-common
```
