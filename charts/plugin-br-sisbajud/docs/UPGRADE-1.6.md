# Helm Upgrade from v1.5.1 to v1.6.0

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.5.1** to **1.6.0**. This is a minor release that introduces support for permanent block operations through the Mensageria integration, alongside the existing Direct permanent block feature.

## Table of Contents

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. Mensageria Permanent Block Support](#1-mensageria-permanent-block-support)
  - [2. Enhanced Validation for Permanent Block Switches](#2-enhanced-validation-for-permanent-block-switches)
- **[Configuration Reference](#configuration-reference)**
  - [New Configuration Fields](#new-configuration-fields)
  - [Updated Validation Rules](#updated-validation-rules)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.6.0 introduces a new permanent block execution path through the Mensageria integration. Previously, the chart only supported permanent block operations through the Direct executor (`sisbajud.direct.permanentBlockEnabled`). This release adds a parallel Mensageria-based permanent block switch (`sisbajud.mensageria.permanentBlockEnabled`) that allows operators to enable permanent block operations through the Mensageria integration.

**Key changes:**

| Component | Change |
|-----------|--------|
| `values.yaml` | New `sisbajud.mensageria.permanentBlockEnabled` flag (default `false`) |
| `templates/_env.tpl` | New `MENSAGERIA_PERMANENT_BLOCK_ENABLED` environment variable |
| `templates/_validate.tpl` | Enhanced validation for both permanent block switches |
| `templates/NOTES.txt` | Updated deployment notes to show both permanent block switches |

**Migration impact:**

- **No breaking changes** — existing deployments continue to work without modification
- **No action required** for operators using only Direct permanent block (the default)
- **Action required** only if enabling Mensageria permanent block (see [Migration Steps](#migration-steps))

> **Note:** Both permanent block switches can coexist. The Direct switch remains enabled by default (`true`), while the Mensageria switch defaults to `false`.

## Features

### 1. Mensageria Permanent Block Support

The chart now supports permanent block operations through the Mensageria integration, controlled by the new `sisbajud.mensageria.permanentBlockEnabled` flag.

**What changed:**

| Setting | v1.5.1 | v1.6.0 |
|---------|--------|--------|
| `sisbajud.mensageria.permanentBlockEnabled` | Not available | `false` (default) |
| `MENSAGERIA_PERMANENT_BLOCK_ENABLED` environment variable | Not set | Set based on `sisbajud.mensageria.permanentBlockEnabled` |

**Why this matters:**

The Mensageria permanent block path provides an alternative execution route for permanent block operations. Unlike the Direct permanent block (which is enabled by default), the Mensageria permanent block must be explicitly enabled and requires the streaming infrastructure to be configured.

**Key differences between Direct and Mensageria permanent block:**

| Aspect | Direct Permanent Block | Mensageria Permanent Block |
|--------|------------------------|----------------------------|
| Default state | Enabled (`true`) | Disabled (`false`) |
| Streaming requirement | Needs `STREAMING_ENABLED=true` and brokers | Needs `STREAMING_ENABLED=true` **written explicitly** and brokers |
| Configuration location | `sisbajud.direct.permanentBlockEnabled` | `sisbajud.mensageria.permanentBlockEnabled` |
| Use case | Default permanent block execution | Alternative execution path through Mensageria |

**Configuration example:**

```yaml
sisbajud:
  mensageria:
    baseUrl: "https://mensageria.internal.example.com"
    permanentBlockEnabled: true  # New in v1.6.0
  
  direct:
    permanentBlockEnabled: true  # Existing, remains default
```

**New environment variable:**

| Variable | Default | Description |
|----------|---------|-------------|
| `MENSAGERIA_PERMANENT_BLOCK_ENABLED` | `false` | Enable permanent block operations through Mensageria. Requires streaming infrastructure and explicit `global.streaming.enabled=true` configuration. |

> **Important:** The Mensageria permanent block switch **never turns the streaming infrastructure on by itself**. You must explicitly set `global.streaming.enabled: true` in your values (not just configure brokers). This is different from the Direct permanent block, which only requires brokers to be configured.

### 2. Enhanced Validation for Permanent Block Switches

The chart's validation logic has been enhanced to support both permanent block switches with consistent requirements.

**What changed:**

The validation template (`templates/_validate.tpl`) now validates both `DIRECT_PERMANENT_BLOCK_ENABLED` and `MENSAGERIA_PERMANENT_BLOCK_ENABLED` with the following requirements:

**Common requirements for both switches:**

1. **Streaming infrastructure:** Both require `STREAMING_ENABLED=true` and `STREAMING_BROKERS` configured
2. **Authentication:** Both require `PLUGIN_AUTH_ENABLED=true` (inbound auth)
3. **Single-tenant mode:** Both require `MULTI_TENANT_ENABLED=false`
4. **Result emitter:** Both require `EXECUTOR_PERMANENT_RESULT_EMITTER_ENABLED` not set to `"false"`

**Mensageria-specific requirement:**

The Mensageria permanent block switch requires `global.streaming.enabled: true` to be **explicitly written** in your values. This is stricter than the Direct switch, which only requires brokers to be configured.

**Before (v1.5.1):**

```yaml
# Validation only checked Direct permanent block
if direct.permanentBlockEnabled == true:
  - require STREAMING_ENABLED=true and STREAMING_BROKERS
  - require PLUGIN_AUTH_ENABLED=true
  - require MULTI_TENANT_ENABLED=false
```

**After (v1.6.0):**

```yaml
# Validation checks both switches with consistent rules
for each switch in [direct.permanentBlockEnabled, mensageria.permanentBlockEnabled]:
  if switch == true:
    - require STREAMING_ENABLED=true and STREAMING_BROKERS
    - require PLUGIN_AUTH_ENABLED=true
    - require MULTI_TENANT_ENABLED=false
    - require result emitter not "false"

# Additional check for Mensageria switch:
if mensageria.permanentBlockEnabled == true:
  - require global.streaming.enabled explicitly written (not just brokers)
```

**New validation error messages:**

The chart will fail to render with specific error messages if requirements are not met:

| Condition | Error Message |
|-----------|---------------|
| Mensageria permanent block enabled without explicit `global.streaming.enabled` | `sisbajud.mensageria.permanentBlockEnabled is true and needs STREAMING_ENABLED=true (written) and STREAMING_BROKERS` |
| Either switch enabled without auth | `[switch path] is true and requires inbound auth on (PLUGIN_AUTH_ENABLED=true)` |
| Either switch enabled in multi-tenant mode | `[switch path] is true and requires a single-tenant install (MULTI_TENANT_ENABLED=false)` |
| Either switch enabled with result emitter disabled | `a permanent block switch is true and EXECUTOR_PERMANENT_RESULT_EMITTER_ENABLED is false` |

> **Note:** The validation logic prevents misconfiguration at render time, ensuring that all permanent block dependencies are satisfied before deployment.

## Configuration Reference

### New Configuration Fields

**sisbajud.mensageria.permanentBlockEnabled**

| Flag | Default | Description |
|------|---------|-------------|
| `sisbajud.mensageria.permanentBlockEnabled` | `false` | Enable permanent block operations through the Mensageria integration. Requires `global.streaming.enabled=true` (explicitly written), `global.streaming.brokers`, `global.auth.enabled=true`, single-tenant mode, and the result emitter not set to `"false"`. |

**Configuration example:**

```yaml
sisbajud:
  mensageria:
    baseUrl: "https://mensageria.internal.example.com"
    permanentBlockEnabled: true
    ca:
      existingSecret: "mensageria-ca"
      key: "ca.crt"
      mountPath: "/etc/plugin-br-sisbajud/mensageria-ca"

global:
  streaming:
    enabled: true  # Must be explicitly set for Mensageria permanent block
    brokers: "kafka-broker-1:9092,kafka-broker-2:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "sisbajud-executor"
  
  auth:
    enabled: true
  
  multiTenant:
    enabled: false

sisbajud:
  app:
    defaultTenantId: "11111111-1111-1111-1111-111111111111"
  
  secrets:
    STREAMING_SASL_PASSWORD: "streaming-password"
    STREAMING_TLS_CA_CERT: "base64-encoded-ca-cert"
```

### Updated Validation Rules

**Streaming configuration requirements:**

| Switch | Streaming Requirement | Configuration Path |
|--------|----------------------|-------------------|
| `direct.permanentBlockEnabled` | `STREAMING_ENABLED=true` and brokers | `global.streaming.brokers` (or `sisbajud.configmap.STREAMING_BROKERS`) |
| `mensageria.permanentBlockEnabled` | `STREAMING_ENABLED=true` **written** and brokers | `global.streaming.enabled: true` **and** `global.streaming.brokers` |

**Common requirements for both switches:**

```yaml
# Required for either permanent block switch to be enabled
global:
  auth:
    enabled: true  # PLUGIN_AUTH_ENABLED=true
  
  multiTenant:
    enabled: false  # MULTI_TENANT_ENABLED=false
  
  streaming:
    brokers: "kafka-broker-1:9092"  # STREAMING_BROKERS
    tlsEnabled: true  # Required in production
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "sisbajud-executor"

sisbajud:
  app:
    defaultTenantId: "11111111-1111-1111-1111-111111111111"
  
  direct:
    permanentResultEmitterEnabled: ""  # Or "true", not "false"
  
  secrets:
    STREAMING_SASL_PASSWORD: "streaming-password"
```

**Mensageria-specific requirement:**

```yaml
# Additional requirement for Mensageria permanent block
global:
  streaming:
    enabled: true  # Must be explicitly written
```

> **Warning:** Setting `sisbajud.direct.permanentResultEmitterEnabled: "false"` will prevent both permanent block switches from working, as the permanent block publishes results through the emitter.

## Migration Steps

### Scenario 1: Existing Deployment (No Changes Required)

If you are using the default Direct permanent block configuration, **no action is required**. The upgrade is a drop-in replacement.

**Verification:**

After upgrading, verify that the Direct permanent block remains enabled:

```bash
kubectl get deployment plugin-br-sisbajud -n sisbajud -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DIRECT_PERMANENT_BLOCK_ENABLED")].value}'
```

Expected output: `true`

```bash
kubectl get deployment plugin-br-sisbajud -n sisbajud -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MENSAGERIA_PERMANENT_BLOCK_ENABLED")].value}'
```

Expected output: `false`

### Scenario 2: Enabling Mensageria Permanent Block

If you want to enable permanent block operations through the Mensageria integration, follow these steps:

**Step 1: Verify streaming infrastructure is configured**

Ensure your streaming infrastructure (Kafka/RedPanda) is deployed and accessible:

```bash
# Verify brokers are reachable from the cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- nc -zv kafka-broker-1 9092
```

**Step 2: Update your values.yaml**

Add the following configuration to your `values.yaml`:

```yaml
global:
  streaming:
    enabled: true  # Must be explicitly set
    brokers: "kafka-broker-1:9092,kafka-broker-2:9092"
    tlsEnabled: true
    saslMechanism: "SCRAM-SHA-512"
    saslUsername: "sisbajud-executor"
  
  auth:
    enabled: true
  
  multiTenant:
    enabled: false

sisbajud:
  app:
    defaultTenantId: "11111111-1111-1111-1111-111111111111"
  
  mensageria:
    baseUrl: "https://mensageria.internal.example.com"
    permanentBlockEnabled: true  # Enable Mensageria permanent block
  
  secrets:
    STREAMING_SASL_PASSWORD: "your-streaming-password"
    STREAMING_TLS_CA_CERT: "base64-encoded-ca-certificate"
```

**Step 3: Validate the configuration**

Before upgrading, validate that the chart will render successfully:

```bash
helm template plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm --version 1.6.0 -n sisbajud -f values.yaml > /dev/null
```

If validation fails, the chart will output a specific error message indicating which requirement is not met.

**Step 4: Upgrade the chart**

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm --version 1.6.0 -n sisbajud -f values.yaml
```

**Step 5: Verify the deployment**

Check that both permanent block switches are configured as expected:

```bash
kubectl get deployment plugin-br-sisbajud -n sisbajud -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MENSAGERIA_PERMANENT_BLOCK_ENABLED")].value}'
```

Expected output: `true`

```bash
kubectl logs -n sisbajud deployment/plugin-br-sisbajud --tail=50 | grep -i "permanent"
```

Look for log entries confirming that both permanent block paths are initialized.

### Scenario 3: Disabling Direct Permanent Block

If you want to disable the Direct permanent block and use only the Mensageria permanent block:

```yaml
sisbajud:
  direct:
    permanentBlockEnabled: false  # Disable Direct permanent block
  
  mensageria:
    permanentBlockEnabled: true  # Enable Mensageria permanent block

global:
  streaming:
    enabled: true  # Required for Mensageria permanent block
    brokers: "kafka-broker-1:9092"
```

> **Warning:** Disabling `direct.permanentBlockEnabled` stops only **new** permanent block operations through the Direct path. Active permanent block operations will continue running until completion. Monitor the `sisbajud_executor_permanent_active_with_switch_off` metric to track active operations with the switch disabled.

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.6.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://ghcr.io/lerianstudio/plugin-br-sisbajud-helm -n sisbajud --version 1.6.0
```
