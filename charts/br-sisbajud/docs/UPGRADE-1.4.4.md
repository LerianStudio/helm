<!-- {% raw %} -->
# Helm Upgrade from v1.4.3 to v1.4.4

## Topics

- **[Fixes](#fixes)**
  - [License requirement enforcement](#license-requirement-enforcement)
  - [Shutdown grace period documentation](#shutdown-grace-period-documentation)
  - [Deployment template terminationGracePeriodSeconds logic](#deployment-template-terminationgraceperiodseconds-logic)

## Fixes

### License requirement enforcement

The chart render now requires `LICENSE_KEY` in **all environments**. v1.4.3 skipped this check in `local`, `development`, `staging`, `e2e` and `test`, but app 1.1.0, the default image of both chart versions, already refused to boot there without a key.

| Setting | v1.4.3 | v1.4.4 |
|---------|--------|--------|
| `LICENSE_KEY` requirement | Required only in production-like environments (not in local, development, staging, e2e, test) | Required in all environments |

**Before (v1.4.3):**

```yaml
# values.yaml comment
# -- organizationIds (must be "global"). LICENSE_KEY is a secret, required in a production-like
# environment (anything but local|development|staging|e2e|test); in those five
# an empty LICENSE_KEY is the app's dev bypass.
license: {}
```

**After (v1.4.4):**

```yaml
# values.yaml comment
# -- organizationIds (must be "global"). LICENSE_KEY is a secret, required in every environment.
license: {}
```

**Template validation logic change:**

**Before (v1.4.3):**

```yaml
{{- /* License (validateLicenseConfig): required in a production-like environment; in
   local|development|staging|e2e|test an empty LICENSE_KEY is the app's dev bypass. */ -}}
{{- if $prodLike -}}
{{- include $req (dict "context" $ "key" "LICENSE_KEY" "secret" true "why" (printf "in a production-like environment (ENVIRONMENT_NAME=%q; the app refuses to boot unlicensed)" $envName) "set" "brSisbajud.secrets.LICENSE_KEY") -}}
{{- end -}}
```

**After (v1.4.4):**

```yaml
{{- /* License (validateLicenseConfig): required in every environment, no unlicensed mode. */ -}}
{{- include $req (dict "context" $ "key" "LICENSE_KEY" "secret" true "why" (printf "(the app refuses to boot unlicensed in every environment; ENVIRONMENT_NAME=%q)" $envName) "set" "brSisbajud.secrets.LICENSE_KEY") -}}
```

**NOTES.txt warning change:**

**Before (v1.4.3):**

```yaml
WARNING: LICENSE_KEY is still the old values-dev placeholder: the license gateway
refuses it and the pod will not boot. Set a real key, or leave it EMPTY in
local|development|staging|e2e|test (the app's dev bypass).
```

**After (v1.4.4):**

```yaml
WARNING: LICENSE_KEY is still the old values-dev placeholder: the license gateway
refuses it and the pod will not boot. Set a real key.
```

#### Migration steps

If you were previously deploying to development, staging, or test environments with an empty or placeholder `LICENSE_KEY`, you must now provide a valid license key.

**1. Obtain a valid license key from Lerian Studio**

Contact Lerian Studio support to obtain a license key for your environment.

**2. Update your values file**

```yaml
brSisbajud:
  secrets:
    LICENSE_KEY: "<your-valid-license-key>"
```

**3. For GitOps with ArgoCD Vault Plugin**

```yaml
brSisbajud:
  secrets:
    LICENSE_KEY: <path:secret/data/br-sisbajud#license-key>
```

> **Important:** The application will refuse to boot without a valid `LICENSE_KEY` in all environments, including development and staging.

> **Warning:** If `LICENSE_KEY` is empty, the v1.4.4 render fails and names `brSisbajud.secrets.LICENSE_KEY`. A key that the license gateway refuses still stops the pod at boot. Set the license key before upgrading.

### Shutdown grace period documentation

The chart now includes clarified documentation about the `terminationGracePeriodSeconds` setting and its relationship to the `SHUTDOWN_DRAIN_DELAY` environment variable.

| Setting | v1.4.3 | v1.4.4 |
|---------|--------|--------|
| `terminationGracePeriodSeconds` comment | "never lower it" | "do not lower it below the shutdown budget" |
| `SHUTDOWN_DRAIN_DELAY` documentation | Counted in the 55s sum | Explicitly documented that default image (app 1.1.0) does not read this variable |

**Before (v1.4.3):**

```yaml
brSisbajud:
  enabled: true
  replicaCount: 1
  # -- 55 = 15s SHUTDOWN_DRAIN_DELAY + 30s shutdown budget + 10s margin; never lower it.
  terminationGracePeriodSeconds: 55
```

**After (v1.4.4):**

```yaml
brSisbajud:
  enabled: true
  replicaCount: 1
  # -- 55 = 15s SHUTDOWN_DRAIN_DELAY + 30s shutdown budget + 10s margin; do not lower it below the shutdown budget.
  # The default image (app 1.1.0) does not read SHUTDOWN_DRAIN_DELAY.
  terminationGracePeriodSeconds: 55
```

**Template comment change:**

**Before (v1.4.3):**

```yaml
{{- /* lib-streaming knobs outside lerian-common.streaming.env. closeTimeoutS must stay
   below the 30s shutdown budget (SHUTDOWN_TIMEOUT), which runs inside the pod's
   terminationGracePeriodSeconds, or SIGKILL cuts the producer drain/flush short. */}}
{{ include $kv (dict "cm" $cm "p" (dict) "f" "shutdownDrainDelay" "k" "SHUTDOWN_DRAIN_DELAY" "d" "15s") }}
```

**After (v1.4.4):**

```yaml
{{- /* lib-streaming knobs outside lerian-common.streaming.env. closeTimeoutS must stay
   below the 30s shutdown budget (SHUTDOWN_TIMEOUT), which runs inside the pod's
   terminationGracePeriodSeconds, or SIGKILL cuts the producer drain/flush short.
   The default image (app 1.1.0) does not read SHUTDOWN_DRAIN_DELAY. */}}
{{ include $kv (dict "cm" $cm "p" (dict) "f" "shutdownDrainDelay" "k" "SHUTDOWN_DRAIN_DELAY" "d" "15s") }}
```

> **Note:** This is a documentation-only change. The default value of `terminationGracePeriodSeconds: 55` remains unchanged. The clarification helps operators understand that the default application image (version 1.1.0) does not honor the `SHUTDOWN_DRAIN_DELAY` environment variable.

> **Important:** If you have customized `terminationGracePeriodSeconds`, ensure it is not lower than the shutdown budget (30 seconds) plus any drain delay and margin. Setting it too low will cause SIGKILL to terminate the application before it can gracefully drain streaming producers.

### Deployment template terminationGracePeriodSeconds logic

The chart now uses a more robust template expression to handle the `terminationGracePeriodSeconds` field, ensuring the default value of 55 is always applied when the field is not explicitly set.

**Before (v1.4.3):**

```yaml
terminationGracePeriodSeconds: {{ .Values.brSisbajud.terminationGracePeriodSeconds | default 55 }}
```

**After (v1.4.4):**

```yaml
terminationGracePeriodSeconds: {{ ternary 55 .Values.brSisbajud.terminationGracePeriodSeconds (kindIs "invalid" .Values.brSisbajud.terminationGracePeriodSeconds) }}
```

#### What changed

The template now uses Helm's `ternary` and `kindIs` functions to detect when `terminationGracePeriodSeconds` is not set (invalid type) and explicitly defaults to 55. `| default 55` also replaced an explicit `0` with 55; the new expression keeps it.

#### Operational impact

An unset value still renders 55. An explicit `brSisbajud.terminationGracePeriodSeconds: 0` rendered 55 in v1.4.3 and now renders `0`. If you set `0`, remove it or set a value at or above the shutdown budget.

```yaml
brSisbajud:
  # Option 1: Omit the field (default 55 is applied)
  # terminationGracePeriodSeconds: 55

  # Option 2: Explicitly set a custom value
  terminationGracePeriodSeconds: 60
```

> **Note:** No action is required unless you set `brSisbajud.terminationGracePeriodSeconds: 0`.

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm -n br-sisbajud --version 1.4.4
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://ghcr.io/lerianstudio/br-sisbajud-helm -n br-sisbajud --version 1.4.4
```
<!-- {% endraw %} -->
