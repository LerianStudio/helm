<!-- {% raw %} -->
# Helm Upgrade from v1.3.0 to v1.4.0

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [AWS KMS key mode now required](#aws-kms-key-mode-now-required)
  - [Image tag verification for AWS KMS](#image-tag-verification-for-aws-kms)
- **[Features](#features)**
  - [1. AWS KMS managed and provided key modes](#1-aws-kms-managed-and-provided-key-modes)
  - [2. AWS KMS timeout and rotation configuration](#2-aws-kms-timeout-and-rotation-configuration)
  - [3. Enhanced KMS configuration precedence](#3-enhanced-kms-configuration-precedence)
- **[Configuration Reference](#configuration-reference)**
  - [New KMS configuration fields](#new-kms-configuration-fields)
  - [New environment variables](#new-environment-variables)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Breaking Changes

### AWS KMS key mode now required

| Setting | v1.3.0 | v1.4.0 |
|---------|--------|--------|
| `KMS_AWS_KEY_MODE` | Not required | **Required** when `KMS_PROVIDER=aws` |
| Valid values | N/A | `managed` or `provided` |
| Chart validation | None | Fails at template rendering if missing |

**Before (v1.3.0):**

When using AWS KMS (`global.kms.vendor: "aws"` or `brSisbajud.kms.vendor: "aws"`), the application would automatically create and manage its own KMS key without explicit configuration.

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"

brSisbajud:
  secrets:
    # Application created its own KMS key automatically
```

**After (v1.4.0):**

You must explicitly declare the key mode using `awsKeyMode`:

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"  # or "provided"

brSisbajud:
  secrets:
    # Key mode is now mandatory
```

> **Important:** The chart will **fail to render** if `KMS_PROVIDER=aws` is set without `KMS_AWS_KEY_MODE`. The application refuses to boot without this configuration.

#### Why this matters

This change enforces explicit key ownership and lifecycle management:

- **`managed` mode**: The application creates and owns the KMS key (same behavior as v1.3.0, now explicit)
- **`provided` mode**: You provide an existing KMS key ARN (new capability in v1.4.0)

#### Migration options

**Option 1: Keep existing behavior (managed mode)**

If you were using AWS KMS in v1.3.0, add `awsKeyMode: "managed"` to maintain the same behavior:

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"
```

Or set it in the dedicated KMS mask:

```yaml
brSisbajud:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"
```

**Option 2: Use an existing KMS key (provided mode)**

If you want to use a pre-existing KMS key:

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
```

> **Warning:** When using `awsKeyMode: "provided"`, you **must** supply `awsKeyArn`. When using `awsKeyMode: "managed"`, `awsKeyArn` **must be empty** (the application creates the key).

**Validation rules:**

| Mode | `awsKeyArn` requirement | Chart behavior |
|------|------------------------|----------------|
| `managed` | Must be empty | Fails if `awsKeyArn` is set |
| `provided` | Must be set | Fails if `awsKeyArn` is missing |

### Image tag verification for AWS KMS

| Setting | v1.3.0 | v1.4.0 |
|---------|--------|--------|
| Minimum image version for AWS KMS | Not enforced | `1.1.0-beta.13` |
| Tag format validation | None | Canonical SemVer required or explicit acknowledgement |
| Acknowledgement flag | N/A | `brSisbajud.kms.allowUnverifiableImageTag` |

**Why this matters:**

Images before `1.1.0-beta.13` ignore `KMS_AWS_KEY_MODE` and `KMS_AWS_KEY_ARN`, silently creating their own KMS key even when you specify `provided` mode. This can lead to:

- Unexpected KMS key creation
- Data encrypted with the wrong key
- Silent configuration drift

The chart now enforces a minimum image version when using AWS KMS to prevent these issues.

#### Tag verification behavior

**Canonical tags (automatically verified):**

The chart accepts tags in the canonical SemVer form `vX.Y.Z[-(alpha|beta|rc).N]` and verifies they are >= `1.1.0-beta.13`:

```yaml
brSisbajud:
  image:
    tag: "1.1.0"  # ✓ Accepted (>= 1.1.0-beta.13)
    # tag: "v1.1.0-beta.13"  # ✓ Accepted (minimum version)
    # tag: "1.0.0"  # ✗ Rejected (< 1.1.0-beta.13)
```

**Non-canonical tags (require acknowledgement):**

Tags that don't match the canonical form are **rejected by default** because the chart cannot verify the version:

- Digest pins: `@sha256:abc123...` or `1.1.0@sha256:abc123...`
- Architecture suffixes: `1.1.0-amd64`
- Build metadata: `1.1.0+build.1`
- Non-SemVer tags: `latest`, `main`, `dev`

To use a non-canonical tag, you must explicitly acknowledge the image is >= `1.1.0-beta.13`:

```yaml
brSisbajud:
  image:
    tag: "1.1.0@sha256:abc123..."  # Digest pin
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"
    allowUnverifiableImageTag: true  # Required for non-canonical tags
```

> **Warning:** Only set `allowUnverifiableImageTag: true` if you are **certain** the image is >= `1.1.0-beta.13`. Using an older image with AWS KMS will cause silent configuration failures.

> **Important:** The acknowledgement flag is **only** read from `brSisbajud.kms.allowUnverifiableImageTag`. Setting `global.kms.allowUnverifiableImageTag` has no effect (the minimum version differs per chart).

#### Migration for non-canonical tags

If you are using a non-canonical tag (e.g., digest pins for immutability, architecture-specific tags, or CI/CD mirror tags):

**Step 1: Verify your image version**

Confirm the image is >= `1.1.0-beta.13`:

```bash
kubectl -n br-sisbajud get deployment br-sisbajud -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Step 2: Add the acknowledgement flag**

```yaml
brSisbajud:
  image:
    tag: "1.1.0@sha256:abc123..."
  kms:
    allowUnverifiableImageTag: true
```

**Step 3: Upgrade the chart**

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm \
  --version 1.4.0 \
  -n br-sisbajud \
  -f values.yaml
```

---

## Features

### 1. AWS KMS managed and provided key modes

The chart now supports two distinct AWS KMS key lifecycle models, configured via `awsKeyMode`.

**Managed mode (application-owned key):**

```yaml
brSisbajud:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"
```

| Setting | Value | Description |
|---------|-------|-------------|
| `awsKeyMode` | `"managed"` | Application creates and owns the KMS key |
| `awsKeyArn` | Must be empty | Chart fails if set |
| Key creation | Automatic | Application creates key at first boot |
| Key rotation | Automatic | AWS manages rotation (if enabled on the key) |

**Environment variables emitted (managed mode):**

```yaml
KMS_PROVIDER: "aws"
AWS_REGION: "us-east-1"
KMS_AWS_KEY_MODE: "managed"
# KMS_AWS_KEY_ARN is not set
```

**Provided mode (operator-owned key):**

```yaml
brSisbajud:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
```

| Setting | Value | Description |
|---------|-------|-------------|
| `awsKeyMode` | `"provided"` | Operator provides an existing KMS key |
| `awsKeyArn` | Required | Full ARN of the KMS key |
| Key creation | Manual | Operator creates key outside Helm |
| Key rotation | Manual | Operator manages rotation (application monitors) |

**Environment variables emitted (provided mode):**

```yaml
KMS_PROVIDER: "aws"
AWS_REGION: "us-east-1"
KMS_AWS_KEY_MODE: "provided"
KMS_AWS_KEY_ARN: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
```

> **Note:** The application validates the ARN format, alias consistency, and region match at boot. The chart only enforces presence/absence rules.

**IAM permissions required:**

| Mode | Required IAM permissions |
|------|-------------------------|
| `managed` | `kms:CreateKey`, `kms:DescribeKey`, `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey` |
| `provided` | `kms:DescribeKey`, `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey`, `kms:GetKeyRotationStatus` (for rotation monitoring) |

### 2. AWS KMS timeout and rotation configuration

The chart now exposes fine-grained AWS KMS client configuration via `brSisbajud.vault`.

**Timeout configuration:**

```yaml
brSisbajud:
  vault:
    awsKmsTimeoutSec: 30  # Default: not set (application default applies)
```

| Flag | Default | Range | Description |
|------|---------|-------|-------------|
| `awsKmsTimeoutSec` | Not set | 1-600 | AWS KMS API call timeout in seconds |

**Environment variable emitted:**

```yaml
KMS_AWS_TIMEOUT_SEC: "30"
```

> **Note:** The chart validates the range (1-600 seconds) at template rendering. Values outside this range cause the upgrade to fail.

**Rotation check interval (provided mode only):**

```yaml
brSisbajud:
  kms:
    vendor: "aws"
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  vault:
    awsKmsRotationCheckIntervalSec: 3600  # Check every hour
```

| Flag | Default | Range | Description |
|------|---------|-------|-------------|
| `awsKmsRotationCheckIntervalSec` | Not set | 1-86400 | Interval (seconds) to check for key rotation in provided mode |

**Environment variable emitted:**

```yaml
KMS_AWS_ROTATION_CHECK_INTERVAL_SEC: "3600"
```

> **Important:** This setting is **only read by the application in provided mode**. In managed mode, the application does not monitor rotation (AWS handles it automatically).

**Validation rules:**

| Setting | Validation | Failure behavior |
|---------|-----------|------------------|
| `awsKmsTimeoutSec` | Must be a whole number 1-600 | Chart fails to render |
| `awsKmsRotationCheckIntervalSec` | Must be a whole number 1-86400 | Chart fails to render |
| `awsKmsRotationCheckIntervalSec` in managed mode | Ignored (not emitted) | No validation |

**Example configuration:**

```yaml
brSisbajud:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  vault:
    awsKmsTimeoutSec: 45
    awsKmsRotationCheckIntervalSec: 7200  # Check every 2 hours
```

### 3. Enhanced KMS configuration precedence

The chart now supports three layers of KMS configuration with explicit precedence rules.

**Configuration precedence (highest to lowest):**

1. `brSisbajud.configmap` (direct environment variable override)
2. `brSisbajud.kms` (service-specific KMS mask)
3. `global.kms` (environment-wide KMS defaults)

**Before (v1.3.0):**

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
```

**After (v1.4.0):**

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"  # Default for all services

brSisbajud:
  kms:
    awsKeyMode: "provided"  # Override for br-sisbajud only
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
```

**Precedence example:**

```yaml
global:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"

brSisbajud:
  kms:
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/abc"
  configmap:
    KMS_AWS_KEY_ARN: "arn:aws:kms:us-east-1:123456789012:key/xyz"
```

**Effective configuration:**

| Field | Source | Value |
|-------|--------|-------|
| `KMS_PROVIDER` | `global.kms.vendor` | `"aws"` |
| `AWS_REGION` | `global.kms.awsRegion` | `"us-east-1"` |
| `KMS_AWS_KEY_MODE` | `brSisbajud.kms.awsKeyMode` | `"provided"` (overrides global) |
| `KMS_AWS_KEY_ARN` | `brSisbajud.configmap.KMS_AWS_KEY_ARN` | `"arn:aws:kms:us-east-1:123456789012:key/xyz"` (highest precedence) |

> **Note:** The `allowUnverifiableImageTag` acknowledgement flag is **only** read from `brSisbajud.kms`. It is **never** read from `global.kms` (the minimum image version differs per chart).

**Updated values.yaml documentation:**

```yaml
global:
  # -- Env-wide KMS (lerian-common.kms.value): vendor | vaultAddr | vaultAuthMethod |
  # vaultRoleId | vaultMount. vendor: hashicorp-vault (default) | aws.
  # br-sisbajud also reads awsRegion, awsKeyMode and awsKeyArn here when vendor=aws
  # (precedence: brSisbajud.configmap > brSisbajud.kms > global.kms; see brSisbajud.kms).
  # allowUnverifiableImageTag is NOT read here (only brSisbajud.kms). The AppRole secret-id
  # and the Vault token are secrets: brSisbajud.secrets.VAULT_APPROLE_SECRET_ID / VAULT_TOKEN.
  kms: {}

brSisbajud:
  # -- KMS mask (same fields as global.kms). br-sisbajud extras with vendor=aws:
  # awsKeyMode (managed | provided; required with aws), awsKeyArn (required with
  # provided, must be empty with managed), allowUnverifiableImageTag (acknowledgement
  # only: set true when brSisbajud.image.tag is not in the canonical form
  # vX.Y.Z[-(alpha|beta|rc).N], e.g. "@" digest pins, arch suffixes, build metadata) to confirm the image is >= 1.1.0-beta.13;
  # read only here, never from global.kms).
  kms: {}
```

---

## Configuration Reference

### New KMS configuration fields

**`brSisbajud.kms` (service-specific KMS mask):**

```yaml
brSisbajud:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"  # or "provided"
    awsKeyArn: ""  # Required when awsKeyMode=provided, must be empty when managed
    allowUnverifiableImageTag: false  # Set true for non-canonical image tags
```

| Flag | Default | Required | Description |
|------|---------|----------|-------------|
| `vendor` | `""` | No | KMS provider (`hashicorp-vault` or `aws`); falls back to `global.kms.vendor` |
| `awsRegion` | `""` | Yes (with AWS) | AWS region; falls back to `global.kms.awsRegion` |
| `awsKeyMode` | `""` | **Yes (with AWS)** | Key lifecycle mode: `managed` or `provided` |
| `awsKeyArn` | `""` | Conditional | KMS key ARN (required with `provided`, must be empty with `managed`) |
| `allowUnverifiableImageTag` | `false` | No | Acknowledge non-canonical image tag is >= `1.1.0-beta.13` |

**`brSisbajud.vault` (AWS KMS client configuration):**

```yaml
brSisbajud:
  vault:
    awsKmsTimeoutSec: 30
    awsKmsRotationCheckIntervalSec: 3600
```

| Flag | Default | Range | Description |
|------|---------|-------|-------------|
| `awsKmsTimeoutSec` | Not set | 1-600 | AWS KMS API call timeout in seconds |
| `awsKmsRotationCheckIntervalSec` | Not set | 1-86400 | Key rotation check interval in seconds (provided mode only) |

### New environment variables

The following environment variables are added to the ConfigMap when using AWS KMS:

| Variable | Source | Default | Description |
|----------|--------|---------|-------------|
| `KMS_AWS_KEY_MODE` | `brSisbajud.kms.awsKeyMode` or `global.kms.awsKeyMode` | None | **Required** with AWS KMS: `managed` or `provided` |
| `KMS_AWS_KEY_ARN` | `brSisbajud.kms.awsKeyArn` or `global.kms.awsKeyArn` | None | KMS key ARN (required with `provided` mode) |
| `KMS_AWS_TIMEOUT_SEC` | `brSisbajud.vault.awsKmsTimeoutSec` | Not set | AWS KMS API timeout (1-600 seconds) |
| `KMS_AWS_ROTATION_CHECK_INTERVAL_SEC` | `brSisbajud.vault.awsKmsRotationCheckIntervalSec` | Not set | Rotation check interval (1-86400 seconds, provided mode only) |

**Template rendering logic:**

```yaml
{{- if eq $kmsProvider "aws" }}
{{- $awsKeyMode := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsKeyMode" "nativeKey" "KMS_AWS_KEY_MODE" "default" "") | trim }}
{{- if $awsKeyMode }}
KMS_AWS_KEY_MODE: {{ $awsKeyMode | quote }}
{{- end }}
{{- $awsKeyArn := include "lerian-common.kms.value" (dict "context" $ "dedicated" $kmsDed "configmap" $cm "field" "awsKeyArn" "nativeKey" "KMS_AWS_KEY_ARN" "default" "") | trim }}
{{- if $awsKeyArn }}
KMS_AWS_KEY_ARN: {{ $awsKeyArn | quote }}
{{- end }}
{{ include $kv (dict "cm" $cm "p" $b.vault "f" "awsKmsTimeoutSec" "k" "KMS_AWS_TIMEOUT_SEC" "opt" true) }}
{{ include $kv (dict "cm" $cm "p" $b.vault "f" "awsKmsRotationCheckIntervalSec" "k" "KMS_AWS_ROTATION_CHECK_INTERVAL_SEC" "opt" true) }}
{{- end }}
```

> **Note:** These variables are only emitted when `KMS_PROVIDER=aws`. They are not present in the ConfigMap when using HashiCorp Vault.

---

## Migration Steps

### Step 1: Determine your current KMS configuration

Check if you are using AWS KMS:

```bash
kubectl -n br-sisbajud get configmap br-sisbajud -o jsonpath='{.data.KMS_PROVIDER}'
```

If the output is `aws`, you **must** add `awsKeyMode` configuration before upgrading.

### Step 2: Choose your key mode

**If you want the application to manage the key (same as v1.3.0 behavior):**

Add `awsKeyMode: "managed"` to your values:

```yaml
brSisbajud:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"
```

**If you want to use an existing KMS key:**

Add `awsKeyMode: "provided"` and the key ARN:

```yaml
brSisbajud:
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "provided"
    awsKeyArn: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
```

### Step 3: Verify your image tag

Check your current image tag:

```bash
kubectl -n br-sisbajud get deployment br-sisbajud -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**If the tag is in canonical form** (e.g., `1.1.0`, `v1.1.0-beta.13`, `1.2.0-rc.1`):

No action required. The chart will verify it is >= `1.1.0-beta.13`.

**If the tag is non-canonical** (e.g., `1.1.0@sha256:abc123...`, `1.1.0-amd64`, `latest`):

Add the acknowledgement flag:

```yaml
brSisbajud:
  image:
    tag: "1.1.0@sha256:abc123..."
  kms:
    allowUnverifiableImageTag: true
```

> **Warning:** Only set this flag if you are **certain** the image is >= `1.1.0-beta.13`.

### Step 4: Update your values file

Merge the new configuration into your existing `values.yaml`:

```yaml
brSisbajud:
  image:
    tag: "1.1.0"  # Or your current tag
  kms:
    vendor: "aws"
    awsRegion: "us-east-1"
    awsKeyMode: "managed"  # Add this
    # allowUnverifiableImageTag: true  # Only if using non-canonical tag
  vault:
    awsKmsTimeoutSec: 30  # Optional: customize timeout
    # awsKmsRotationCheckIntervalSec: 3600  # Only with provided mode
```

### Step 5: Preview the changes

```bash
helm diff upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm \
  --version 1.4.0 \
  -n br-sisbajud \
  -f values.yaml
```

Verify the ConfigMap diff shows:

```yaml
+ KMS_AWS_KEY_MODE: "managed"
```

### Step 6: Upgrade the chart

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm \
  --version 1.4.0 \
  -n br-sisbajud \
  -f values.yaml
```

### Step 7: Verify the deployment

Check the ConfigMap contains the new variables:

```bash
kubectl -n br-sisbajud get configmap br-sisbajud -o yaml | grep KMS_AWS
```

Expected output:

```yaml
KMS_AWS_KEY_MODE: "managed"
```

Check the pods are running:

```bash
kubectl -n br-sisbajud get pods -l app.kubernetes.io/instance=br-sisbajud
```

Check the application logs for KMS initialization:

```bash
kubectl -n br-sisbajud logs -l app.kubernetes.io/instance=br-sisbajud --tail=50 | grep -i kms
```

---

## Preview changes before upgrading

```bash
helm diff upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.4.0 -n br-sisbajud
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-sisbajud oci://registry-1.docker.io/lerianstudio/br-sisbajud-helm --version 1.4.0 -n br-sisbajud
```
<!-- {% endraw %} -->
