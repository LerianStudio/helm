<!-- {% raw %} -->
# Helm Upgrade from v1.0.0 to v1.1.0

This guide covers the upgrade of the `plugin-br-sisbajud` Helm chart from version **1.0.0** to **1.1.0**. This minor release introduces AWS KMS key management modes, allowing operators to choose between application-managed keys and customer-provided keys for envelope encryption in AWS deployments.

## Table of Contents

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. AWS KMS Key Management Modes](#1-aws-kms-key-management-modes)
  - [2. AWS KMS Timeout and Rotation Configuration](#2-aws-kms-timeout-and-rotation-configuration)
  - [3. Image Tag Verification for AWS KMS](#3-image-tag-verification-for-aws-kms)
- **[Configuration Reference](#configuration-reference)**
  - [AWS KMS Key Mode Configuration](#aws-kms-key-mode-configuration)
  - [AWS KMS Timeout Configuration](#aws-kms-timeout-configuration)
  - [Image Tag Acknowledgement](#image-tag-acknowledgement)
  - [Environment Variables](#environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

Version 1.1.0 introduces AWS KMS key management modes for the `plugin-br-sisbajud` chart. Operators using AWS KMS (`global.kms.vendor: aws`) must now explicitly configure how the application manages encryption keys:

- **Managed mode**: The application creates and owns the KMS key (default behavior in v1.0.0)
- **Provided mode**: The operator provides existing KMS keys (new in v1.1.0)

This release also adds optional timeout and rotation interval configuration for AWS KMS operations, and enforces minimum image version requirements when using AWS KMS to prevent silent key creation by older images.

> **Important:** This upgrade **requires configuration changes** for all deployments using AWS KMS. The chart will fail to render without the new `awsKeyMode` setting.

## Features

### 1. AWS KMS Key Management Modes

The chart now supports two distinct key management modes when using AWS KMS, allowing operators to choose between application-managed keys (BYOC/single-tenant default) and customer-provided keys (enterprise compliance scenarios).

**Key mode comparison:**

| Mode | Description | Use Case | Key Ownership |
|------|-------------|----------|---------------|
| `managed` | Application creates and owns the KMS key | BYOC deployments, development | Application |
| `provided` | Operator provides existing KMS keys | Enterprise compliance, centralized key management | Customer |

**Configuration changes:**

| Setting | v1.0.0 | v1.1.0 |
|---------|--------|--------|
| `global.kms.awsKeyMode` | Not available | Required with `vendor: aws` |
| `global.kms.awsKeyArn` | Not available | Required with `awsKeyMode: provided` |
| `global.kms.awsCredentialsKeyArn` | Not available | Required with `awsKeyMode: provided` |

**Managed mode configuration (application creates keys):**

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"
```

> **Note:** With `awsKeyMode: managed`, the `awsKeyArn` and `awsCredentialsKeyArn` fields must be empty or unset. The application will create and manage its own KMS keys.

**Provided mode configuration (customer-provided keys):**

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    awsCredentialsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/87654321-4321-4321-4321-210987654321"
```

> **Important:** The `awsKeyArn` and `awsCredentialsKeyArn` must reference **distinct** KMS keys. The chart will fail validation if they are identical.

**Dedicated KMS configuration (service-level override):**

The `sisbajud.kms` block can override `global.kms` settings:

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"

sisbajud:
  kms:
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/service-specific-key"
    awsCredentialsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/service-specific-creds-key"
```

> **Note:** The `awsKeyMode`, `awsKeyArn`, and `awsCredentialsKeyArn` fields are read from both `global.kms` and `sisbajud.kms`, with `sisbajud.kms` taking precedence. These fields **cannot** be set via `sisbajud.configmap` (the schema rejects them).

**Multi-tenant restriction:**

AWS KMS is restricted to single-tenant (BYOC) deployments only. The chart will fail validation if both conditions are true:

- `global.kms.vendor: aws` (or `sisbajud.kms.vendor: aws`)
- `global.multiTenant.enabled: true` (or `sisbajud.configmap.MULTI_TENANT_ENABLED: "true"`)

```yaml
# This configuration will FAIL validation:
global:
  kms:
    vendor: "aws"
  multiTenant:
    enabled: true  # Not allowed with AWS KMS
```

> **Warning:** If you are using AWS KMS, ensure `global.multiTenant.enabled` is `false` or unset. Multi-tenant deployments must use HashiCorp Vault (`vendor: hashicorp-vault`).

### 2. AWS KMS Timeout and Rotation Configuration

The chart now supports optional timeout and rotation interval configuration for AWS KMS operations, validated in all key modes.

**New configuration fields:**

| Flag | Default | Valid Range | Description |
|------|---------|-------------|-------------|
| `sisbajud.vault.awsKmsTimeoutSec` | (none) | 1-600 | AWS KMS operation timeout in seconds |
| `sisbajud.vault.awsKmsRotationCheckIntervalSec` | (none) | 1-86400 | Key rotation check interval in seconds |

**Configuration example:**

```yaml
sisbajud:
  vault:
    awsKmsTimeoutSec: "30"
    awsKmsRotationCheckIntervalSec: "3600"
```

> **Note:** These settings are optional. If omitted, the application uses its internal defaults. Both settings are validated in **every** AWS key mode (managed and provided).

**Template changes:**

**Before (v1.0.0):**

```yaml
{{- with include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsRegion" "nativeKey" "AWS_REGION" "default" "") }}
AWS_REGION: {{ . | quote }}
{{- end }}
```

**After (v1.1.0):**

```yaml
{{- with include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsRegion" "nativeKey" "AWS_REGION" "default" "") }}
AWS_REGION: {{ . | quote }}
{{- end }}
{{- /* aws key modes (plugin-br-sisbajud#324): rendered only when the effective provider is aws */}}
{{- if eq $kmsProvider "aws" }}
{{- $awsKeyMode := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsKeyMode" "nativeKey" "KMS_AWS_KEY_MODE" "default" "") | trim }}
{{- if $awsKeyMode }}
KMS_AWS_KEY_MODE: {{ $awsKeyMode | quote }}
{{- end }}
{{- $awsKeyArn := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsKeyArn" "nativeKey" "KMS_AWS_KEY_ARN" "default" "") | trim }}
{{- if $awsKeyArn }}
KMS_AWS_KEY_ARN: {{ $awsKeyArn | quote }}
{{- end }}
{{- $awsCredArn := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsCredentialsKeyArn" "nativeKey" "KMS_AWS_CREDENTIALS_KEY_ARN" "default" "") | trim }}
{{- if $awsCredArn }}
KMS_AWS_CREDENTIALS_KEY_ARN: {{ $awsCredArn | quote }}
{{- end }}
{{- include $kv (dict "cm" $cm "p" $s.vault "f" "awsKmsTimeoutSec" "k" "KMS_AWS_TIMEOUT_SEC" "opt" true) }}
{{- include $kv (dict "cm" $cm "p" $s.vault "f" "awsKmsRotationCheckIntervalSec" "k" "KMS_AWS_ROTATION_CHECK_INTERVAL_SEC" "opt" true) }}
{{- end }}
```

**Operational impact:**

- The new environment variables are rendered **only** when `KMS_PROVIDER=aws`
- The timeout and rotation interval settings are optional; omitting them uses application defaults
- The key mode and ARN settings are required for AWS KMS deployments (see [Migration Steps](#migration-steps))

### 3. Image Tag Verification for AWS KMS

The chart now enforces minimum image version requirements when using AWS KMS to prevent older images from silently creating their own KMS keys.

**Image version requirements:**

| KMS Provider | Minimum Image Tag | Reason |
|--------------|-------------------|--------|
| `aws` | `1.1.0-beta.1` | Older images ignore `KMS_AWS_KEY_MODE` and create their own keys |
| `hashicorp-vault` | (none) | No minimum version requirement |

**Tag verification rules:**

1. **Canonical tags** (e.g., `v1.1.0`, `1.1.0-beta.1`, `1.2.0-rc.1`) are verified against the minimum version
2. **Non-canonical tags** (e.g., `latest`, `@sha256:...`, `1.1.0-amd64`, `1.1.0+build`) fail closed unless acknowledged

**Configuration example (canonical tag):**

```yaml
sisbajud:
  image:
    tag: "1.1.0"  # Canonical form, verified automatically
```

**Configuration example (non-canonical tag with acknowledgement):**

```yaml
sisbajud:
  image:
    tag: "1.1.0-amd64"  # Non-canonical form
  kms:
    allowUnverifiableImageTag: true  # Acknowledges tag is >= 1.1.0-beta.1
```

> **Warning:** The `allowUnverifiableImageTag` flag is read **only** from `sisbajud.kms`, not from `global.kms`. This is intentional because the minimum image version differs per chart.

**Validation behavior:**

| Tag Format | Example | Behavior |
|------------|---------|----------|
| Canonical SemVer | `1.1.0`, `v1.2.0-beta.1` | Verified against minimum version |
| Below minimum | `1.0.0`, `1.1.0-alpha.1` | Fails with error message |
| Digest pin | `@sha256:abc123...` | Fails unless `allowUnverifiableImageTag: true` |
| Arch suffix | `1.1.0-amd64` | Fails unless `allowUnverifiableImageTag: true` |
| Build metadata | `1.1.0+build.123` | Fails unless `allowUnverifiableImageTag: true` |
| Non-SemVer | `latest`, `stable` | Fails unless `allowUnverifiableImageTag: true` |

**Template validation changes:**

**Before (v1.0.0):**

```yaml
{{- if not (include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsRegion" "nativeKey" "AWS_REGION" "default" "")) -}}
{{- include $f (dict "msg" "AWS_REGION is required with KMS_PROVIDER=aws." "set" "global.kms.awsRegion (or sisbajud.kms.awsRegion)") -}}
{{- end -}}
```

**After (v1.1.0):**

```yaml
{{- if not (include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsRegion" "nativeKey" "AWS_REGION" "default" "")) -}}
{{- include $f (dict "msg" "AWS_REGION is required with KMS_PROVIDER=aws." "set" "global.kms.awsRegion (or sisbajud.kms.awsRegion)") -}}
{{- end -}}
{{- /* Multi-tenant restriction */}}
{{- if eq (include "plugin-br-sisbajud.multiTenantEnabled" .) "true" -}}
{{- include $f (dict "msg" "KMS_PROVIDER=aws is single-tenant (BYOC) only; the app refuses it with MULTI_TENANT_ENABLED=true." "set" "global.multiTenant.enabled=false (or KMS_PROVIDER=vault)") -}}
{{- end -}}
{{- /* Key mode validation */}}
{{- $awsMode := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsKeyMode" "nativeKey" "KMS_AWS_KEY_MODE" "default" "") | trim -}}
{{- if not (has $awsMode (list "managed" "provided")) -}}
{{- include $f (dict "msg" (printf "KMS_PROVIDER=aws now requires KMS_AWS_KEY_MODE (managed | provided), got %q." $awsMode) "set" "sisbajud.kms.awsKeyMode (or global.kms.awsKeyMode)") -}}
{{- end -}}
{{- /* ARN validation for provided mode */}}
{{- $awsKeyArn := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsKeyArn" "nativeKey" "KMS_AWS_KEY_ARN" "default" "") | trim -}}
{{- $awsCredArn := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsCredentialsKeyArn" "nativeKey" "KMS_AWS_CREDENTIALS_KEY_ARN" "default" "") | trim -}}
{{- if eq $awsMode "provided" -}}
{{- if not $awsKeyArn -}}
{{- include $f (dict "msg" "KMS_AWS_KEY_ARN is required when KMS_AWS_KEY_MODE=provided." "set" "sisbajud.kms.awsKeyArn (or global.kms.awsKeyArn)") -}}
{{- end -}}
{{- if not $awsCredArn -}}
{{- include $f (dict "msg" "KMS_AWS_CREDENTIALS_KEY_ARN is required when KMS_AWS_KEY_MODE=provided." "set" "sisbajud.kms.awsCredentialsKeyArn (or global.kms.awsCredentialsKeyArn)") -}}
{{- end -}}
{{- if eq $awsKeyArn $awsCredArn -}}
{{- include $f (dict "msg" "KMS_AWS_KEY_ARN and KMS_AWS_CREDENTIALS_KEY_ARN must name distinct keys." "set" "sisbajud.kms.awsKeyArn / sisbajud.kms.awsCredentialsKeyArn") -}}
{{- end -}}
{{- else -}}
{{- if $awsKeyArn -}}
{{- include $f (dict "msg" "KMS_AWS_KEY_ARN must be empty when KMS_AWS_KEY_MODE=managed (the app creates and owns the key)." "set" "unset sisbajud.kms.awsKeyArn and global.kms.awsKeyArn, or sisbajud.kms.awsKeyMode=provided") -}}
{{- end -}}
{{- if $awsCredArn -}}
{{- include $f (dict "msg" "KMS_AWS_CREDENTIALS_KEY_ARN must be empty when KMS_AWS_KEY_MODE=managed (the app creates and owns the key)." "set" "unset sisbajud.kms.awsCredentialsKeyArn and global.kms.awsCredentialsKeyArn, or sisbajud.kms.awsKeyMode=provided") -}}
{{- end -}}
{{- end -}}
{{- /* Image tag verification */}}
{{- $rawTag := $.Values.sisbajud.image.tag | default $.Chart.AppVersion | toString -}}
{{- $min := "1.1.0-beta.1" -}}
{{- $ackTag := eq (toString (($s.kms | default dict).allowUnverifiableImageTag)) "true" -}}
{{- if regexMatch "^v?(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-(alpha|beta|rc)\\.(0|[1-9][0-9]*))?$" $rawTag -}}
{{- if semverCompare (printf "<%s" $min) (trimPrefix "v" $rawTag) -}}
{{- include $f (dict "msg" (printf "image tag %q with KMS_PROVIDER=aws ignores KMS_AWS_KEY_MODE/KMS_AWS_KEY_ARN and creates its own KMS key." $rawTag) "set" (printf "sisbajud.image.tag >= %s" $min)) -}}
{{- end -}}
{{- else if not $ackTag -}}
{{- include $f (dict "msg" (printf "image tag %q is not in the canonical form vX.Y.Z[-(alpha|beta|rc).N] (digest pins, arch suffixes, build metadata and non-SemVer tags are refused), so the chart cannot verify it is >= %s (older images with KMS_PROVIDER=aws ignore KMS_AWS_KEY_MODE/KMS_AWS_KEY_ARN and create their own KMS key)." $rawTag $min) "set" (printf "a canonical sisbajud.image.tag >= %s, or sisbajud.kms.allowUnverifiableImageTag: true to acknowledge the image is >= %s" $min $min)) -}}
{{- end -}}
```

**Operational impact:**

- Deployments using canonical image tags (e.g., `1.1.0`, `v1.2.0-beta.1`) are verified automatically
- Deployments using non-canonical tags (e.g., digest pins, arch suffixes) must set `sisbajud.kms.allowUnverifiableImageTag: true`
- The acknowledgement flag is intentionally ignored in `global.kms` to allow per-chart minimum versions

## Configuration Reference

### AWS KMS Key Mode Configuration

**Managed mode (application creates keys):**

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"
```

**Provided mode (customer-provided keys):**

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    awsCredentialsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/87654321-4321-4321-4321-210987654321"
```

**Service-level override:**

```yaml
sisbajud:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/service-key"
    awsCredentialsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/service-creds-key"
```

### AWS KMS Timeout Configuration

```yaml
sisbajud:
  vault:
    awsKmsTimeoutSec: "30"
    awsKmsRotationCheckIntervalSec: "3600"
```

| Flag | Default | Valid Range | Description |
|------|---------|-------------|-------------|
| `awsKmsTimeoutSec` | (application default) | 1-600 | AWS KMS operation timeout in seconds |
| `awsKmsRotationCheckIntervalSec` | (application default) | 1-86400 | Key rotation check interval in seconds (validated in all modes) |

### Image Tag Acknowledgement

```yaml
sisbajud:
  image:
    tag: "1.1.0-amd64"  # Non-canonical tag
  kms:
    allowUnverifiableImageTag: true  # Acknowledges tag is >= 1.1.0-beta.1
```

> **Note:** The `allowUnverifiableImageTag` flag is read **only** from `sisbajud.kms`, not from `global.kms`.

### Environment Variables

The following environment variables are added in v1.1.0 (rendered only when `KMS_PROVIDER=aws`):

| Variable | Source | Description |
|----------|--------|-------------|
| `KMS_AWS_KEY_MODE` | `global.kms.awsKeyMode` or `sisbajud.kms.awsKeyMode` | Key management mode: `managed` or `provided` |
| `KMS_AWS_KEY_ARN` | `global.kms.awsKeyArn` or `sisbajud.kms.awsKeyArn` | ARN of the KMS key (required with `provided` mode) |
| `KMS_AWS_CREDENTIALS_KEY_ARN` | `global.kms.awsCredentialsKeyArn` or `sisbajud.kms.awsCredentialsKeyArn` | ARN of the credentials KMS key (required with `provided` mode, must differ from `KMS_AWS_KEY_ARN`) |
| `KMS_AWS_TIMEOUT_SEC` | `sisbajud.vault.awsKmsTimeoutSec` | AWS KMS operation timeout in seconds (optional, validated 1-600) |
| `KMS_AWS_ROTATION_CHECK_INTERVAL_SEC` | `sisbajud.vault.awsKmsRotationCheckIntervalSec` | Key rotation check interval in seconds (optional, validated 1-86400) |

## Migration Steps

### For deployments NOT using AWS KMS

No action required. If you are using HashiCorp Vault (`global.kms.vendor: hashicorp-vault`) or have not configured KMS, this upgrade is a drop-in replacement.

```bash
helm upgrade plugin-br-sisbajud oci://registry-1.docker.io/lerianstudio/plugin-br-sisbajud-helm --version 1.1.0 -n plugin-br-sisbajud
```

### For deployments using AWS KMS

**Required action:** Add the `awsKeyMode` configuration to your values file.

#### Option 1: Managed mode (application creates keys)

If your current deployment allows the application to create and manage its own KMS keys (the default behavior in v1.0.0), configure managed mode:

1. Add the `awsKeyMode` setting to your values file:

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"  # Add this line
```

2. Ensure `awsKeyArn` and `awsCredentialsKeyArn` are **not set** in either `global.kms` or `sisbajud.kms`:

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"
    # awsKeyArn: ""  # Must be empty or unset
    # awsCredentialsKeyArn: ""  # Must be empty or unset
```

3. Upgrade the chart:

```bash
helm upgrade plugin-br-sisbajud oci://registry-1.docker.io/lerianstudio/plugin-br-sisbajud-helm --version 1.1.0 -n plugin-br-sisbajud -f values.yaml
```

#### Option 2: Provided mode (customer-provided keys)

If you want to provide your own KMS keys (new in v1.1.0), configure provided mode:

1. Create or identify two **distinct** KMS keys in AWS:
   - One for data encryption (`awsKeyArn`)
   - One for credentials encryption (`awsCredentialsKeyArn`)

2. Add the key mode and ARNs to your values file:

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    awsCredentialsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/87654321-4321-4321-4321-210987654321"
```

3. Ensure the IAM role or service account has permissions to use both keys:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource": [
        "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012",
        "arn:aws:kms:us-east-1:123456789012:key/87654321-4321-4321-4321-210987654321"
      ]
    }
  ]
}
```

4. Upgrade the chart:

```bash
helm upgrade plugin-br-sisbajud oci://registry-1.docker.io/lerianstudio/plugin-br-sisbajud-helm --version 1.1.0 -n plugin-br-sisbajud -f values.yaml
```

> **Important:** The two KMS key ARNs must be **distinct**. The chart will fail validation if they are identical.

### For deployments using non-canonical image tags

If you are using a non-canonical image tag (e.g., digest pin, arch suffix, build metadata) with AWS KMS, you must acknowledge that the image is >= 1.1.0-beta.1:

```yaml
sisbajud:
  image:
    tag: "1.1.0-amd64"  # Non-canonical tag
  kms:
    allowUnverifiableImageTag: true  # Acknowledges tag is >= 1.1.0-beta.1
```

> **Note:** Canonical tags (e.g., `1.1.0`, `v1.2.0-beta.1`) are verified automatically and do not require the acknowledgement flag.

### For multi-tenant deployments

If you are using AWS KMS with `global.multiTenant.enabled: true`, the upgrade will fail validation. AWS KMS is restricted to single-tenant (BYOC) deployments only.

**Migration options:**

1. **Switch to HashiCorp Vault:**

```yaml
global:
  kms:
    vendor: "hashicorp-vault"
    vaultAddr: "https://vault.internal:8200"
    vaultAuthMethod: "approle"
    vaultRoleId: "role-id-here"
    vaultMount: "transit"
  multiTenant:
    enabled: true
```

2. **Disable multi-tenant mode:**

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"
  multiTenant:
    enabled: false  # Required with AWS KMS
```

## Preview changes before upgrading

```bash
helm diff upgrade plugin-br-sisbajud oci://registry-1.docker.io/lerianstudio/plugin-br-sisbajud-helm --version 1.1.0 -n plugin-br-sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade plugin-br-sisbajud oci://registry-1.docker.io/lerianstudio/plugin-br-sisbajud-helm --version 1.1.0 -n plugin-br-sisbajud
```
<!-- {% endraw %} -->
