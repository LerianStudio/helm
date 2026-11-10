# Helm Upgrade from v1.x to v2.x

This guide covers the upgrade from `alloy-lerian` chart version **1.0.0** to **2.0.0**. This major version changes the default behavior of Fleet Management and revises the regulated data sanitization rules to reduce false positives and clarify what is masked versus what stays in clear.

---

## Topics

- **[Breaking Changes](#breaking-changes)**
  - [Fleet Management Default Behavior](#fleet-management-default-behavior)
  - [Sanitization Rule Changes](#sanitization-rule-changes)
- **[Features](#features)**
  - [1. Identifier Classification Policy](#1-identifier-classification-policy)
  - [2. Reduced False Positives in Sanitization](#2-reduced-false-positives-in-sanitization)
  - [3. Pix Key Masking by Label](#3-pix-key-masking-by-label)
  - [4. Improved Credential Masking](#4-improved-credential-masking)
- **[Configuration Reference](#configuration-reference)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

---

## Breaking Changes

### Fleet Management Default Behavior

Fleet Management is now **enabled by default**. In v1.0.0, remote configuration was opt-in; in v2.0.0, it is the default operational mode.

| Setting | v1.0.0 | v2.0.0 |
|---------|--------|--------|
| `fleetManagement.enabled` | `false` (opt-in) | `true` (default) |
| Local config behavior | Full pipeline rendered locally | Only `logging` and `remotecfg` blocks; collection pipeline fetched remotely |

**What this means:**

- Clusters upgrading to v2.0.0 will **automatically switch to Fleet Management** unless explicitly disabled
- If the Fleet endpoint is unreachable, the agent will collect **nothing** until connectivity is restored
- Sanitization rules remain in the local config and cannot be disabled remotely (unchanged from v1.0.0)

**Migration Steps:**

#### Option 1: Accept Fleet Management (recommended)

No action required. The chart will enable Fleet Management on upgrade.

**Verify Fleet connectivity before upgrading:**

```bash
curl -I https://fleet.lerian.io
```

If the endpoint is reachable, proceed with the upgrade.

#### Option 2: Disable Fleet Management

If you need to keep the full collection pipeline in the local config (e.g., for air-gapped environments or during Fleet service maintenance), explicitly disable Fleet Management:

```yaml
fleetManagement:
  enabled: false
```

> **Warning:** Disabling Fleet Management is the disaster recovery procedure. The local config will render the full collection pipeline, but you will not receive remote configuration updates.

**To disable Fleet Management during upgrade:**

```bash
helm upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm \
  --version 2.0.0 \
  -n alloy-lerian \
  --set fleetManagement.enabled=false
```

### Sanitization Rule Changes

The sanitization processor has been revised to reduce false positives and clarify the classification of identifiers. Several rules have been **removed** or **replaced**.

| Rule | v1.0.0 | v2.0.0 | Impact |
|------|--------|--------|--------|
| CPF (11-digit document) | Masked by form | **Removed** — stays in clear | CPF values will no longer be masked |
| CNPJ (14-digit document) | Masked by form | **Removed** — stays in clear | CNPJ values will no longer be masked |
| Opaque resource identifiers (`acc_`, `txn_`, `cus_`, `ord_`) | Masked after 4 characters | **Removed** — stays in clear | Resource IDs will no longer be masked |
| Pix key (UUID form) | Masked by UUID pattern | **Replaced** — masked by field label | Only labeled Pix keys are masked |

**What stays masked (unchanged):**

- Full names (3+ words)
- Email addresses (local part only, domain preserved)
- Phone numbers (subscriber number masked, area code preserved)
- Bank account and branch numbers
- Postal addresses (entire value)
- Credentials (passwords, tokens, API keys, secrets)

**What now stays in clear (new policy):**

- CPF (11-digit fiscal document)
- CNPJ (14-digit fiscal document)
- Resource identifiers with semantic prefixes (`acc_`, `txn_`, `cus_`, `ord_`)
- UUIDs (unless labeled as a Pix key)
- Matricula, contract numbers, and other business identifiers

**Why this changed:**

The v1.0.0 rules masked identifiers by **form** (any 11-digit run, any 14-digit run, any UUID), which caused false positives:

- Kubernetes `resourceVersion` values were masked (`objectRV=91656472123456` → `objectRV=91************`)
- Unix epoch timestamps were masked (`ts=1787934092000` → `ts=17************`)
- SHA hashes were partially masked when they contained 11 consecutive digits
- Process IDs were masked (`pid=12345678901` → `pid=123********`)

The v2.0.0 policy classifies identifiers by **purpose**, not form:

- **Identifiers** (CPF, CNPJ, UUID, resource ID) stay in clear — they are necessary for correlation and diagnosis
- **Personal data** (names, email, phone, address) is masked — it has no diagnostic value
- **Credentials** (passwords, tokens, keys) are masked — leaking them is an exploitable security incident

> **Important:** This is a **policy change**, not a bug fix. The v1.0.0 rules were working as designed; the v2.0.0 rules reflect a revised understanding of what constitutes regulated data in a diagnostic context.

**Migration Steps:**

No operator action is required. The sanitization rules are embedded in the chart templates and will be updated automatically on upgrade.

**If you need the v1.0.0 masking behavior:**

The v1.0.0 rules cannot be restored via configuration. If your compliance requirements mandate masking CPF, CNPJ, or resource identifiers, you must:

1. Fork the chart and restore the removed rules in `templates/_sanitizacao.tpl`
2. Deploy the forked chart instead of the upstream release

> **Warning:** Restoring the v1.0.0 rules will also restore the false positives (masked `resourceVersion`, `pid`, epoch timestamps). There is no configuration flag to enable "strict masking" — this is a deliberate design decision to avoid creating a compliance theater mode that silently corrupts diagnostic data.

---

## Features

### 1. Identifier Classification Policy

The chart now distinguishes between **identifiers** (which stay in clear) and **personal data** (which is masked).

**Identifiers (stay in clear):**

- CPF (11-digit fiscal document)
- CNPJ (14-digit fiscal document)
- Matricula, contract numbers
- UUIDs (unless labeled as a Pix key)
- Resource identifiers with semantic prefixes (`acc_`, `txn_`, `cus_`, `ord_`)

**Personal data (masked):**

- Full names (3+ words)
- Email addresses (local part only)
- Phone numbers (subscriber number only)
- Postal addresses (entire value)
- Bank account and branch numbers
- Pix keys (when labeled)

**Credentials (masked):**

- Passwords, secrets, API keys, access tokens
- Bearer, Basic, Digest authentication headers
- JWT tokens

**Rationale:**

Identifiers are necessary for correlation and diagnosis. Masking them creates gaps in observability without reducing compliance risk — a CPF that appears in a log line is already indexed at the destination, and masking it in transit does not retroactively remove it from storage.

Personal data and credentials, by contrast, have no diagnostic value. A masked name or password does not impair troubleshooting, and leaking them creates compliance or security incidents.

> **Note:** This policy is documented in the chart README under "Regulated-data sanitisation" and is verified against the pinned Alloy version (1.18.1).

### 2. Reduced False Positives in Sanitization

The v2.0.0 rules eliminate false positives that corrupted diagnostic data in v1.0.0.

**Before (v1.0.0):**

```yaml
# CPF rule (11 digits with boundary check)
`replace_pattern(body, "([^0-9A-Za-z]|^)([0-9]{3})([0-9]{8})([^0-9A-Za-z]|$)", "$1$2********$4")`,

# CNPJ rule (14 digits with boundary check)
`replace_pattern(body, "([^0-9A-Za-z]|^)([0-9]{2})([0-9]{12})([^0-9A-Za-z]|$)", "$1$2************$4")`,

# Opaque resource identifier rule
`replace_pattern(body, "((?:acc|txn|cus|ord)_[0-9a-zA-Z]{4})[0-9a-zA-Z]{4,}([^0-9a-zA-Z_]|$)", "$1******$2")`,
```

**After (v2.0.0):**

```yaml
# CPF, CNPJ, and resource identifier rules removed
# Identifiers stay in clear by policy
```

**Measured impact (v1.0.0 false positives, now resolved):**

| Value | v1.0.0 Behavior | v2.0.0 Behavior |
|-------|-----------------|-----------------|
| `objectRV=91656472123456` | Masked to `objectRV=91************` | Stays in clear |
| `ts=1787934092000` | Masked to `ts=17************` | Stays in clear |
| `pid=12345678901` | Masked to `pid=123********` | Stays in clear |
| `acc_9f8e7d6c5b4a` | Masked to `acc_9f8e******` | Stays in clear |

> **Important:** The v1.0.0 rules had boundary checks to avoid masking hex strings and SHA hashes, but they could not distinguish between a CPF and a Kubernetes `resourceVersion` — both are 11-digit runs delimited by `=` and end-of-line. The v2.0.0 policy resolves this by not masking identifiers at all.

### 3. Pix Key Masking by Label

Pix keys are now masked **only when labeled** as `pixKey`, `pix_key`, `chave_pix`, or `chavePix` (case-insensitive).

**Before (v1.0.0):**

```yaml
# Pix key rule (UUID form only)
`replace_pattern(body, "([0-9a-fA-F]{8})-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-([0-9a-fA-F]{12})", "$1-****-****-****-$2")`,
```

**After (v2.0.0):**

```yaml
# Pix key rule (by field label, any value form)
`replace_pattern(body, "(?i)((?:chave_?pix|pix_?key)\\x22? *[=:] *\\x22?)[^\\s\\x22,;}]+", "$1**********")`,
```

**What this means:**

- A UUID that is **not labeled** as a Pix key will stay in clear
- A Pix key that is a **CPF, CNPJ, email, or phone number** will be masked (by the field label, not by the value form)
- The rule matches JSON, key-value pairs, and accepts spaces around the separator

**Examples:**

| Log line | v1.0.0 | v2.0.0 |
|----------|--------|--------|
| `pixKey=550e8400-e29b-41d4-a716-446655440000` | Masked | Masked |
| `request_id=550e8400-e29b-41d4-a716-446655440000` | Masked | **Stays in clear** |
| `{"pixKey": "05147290150"}` | **Stays in clear** (not UUID) | Masked |
| `{"pix_key" : "user@example.com"}` | **Stays in clear** (not UUID) | Masked |

> **Note:** The `\x22` escape is the JSON double quote. A literal quote would hide the rule from the extractor that diffs this file against the Fleet configuration.

### 4. Improved Credential Masking

The credential masking rules now handle quoted values and preserve both the field name and the quotes.

**Before (v1.0.0):**

```yaml
# Bearer/Basic/Digest/Token/API key
`replace_pattern(body, "(?i)((?:bearer|basic|digest|token|apikey|api_key)[=: ] ?)[A-Za-z0-9._~+/=-]{8,}", "$1**********")`,

# Password/secret assignment
`replace_pattern(body, "(?i)((?:password|passwd|senha|secret|client_secret|access_token|refresh_token|private_key)[=:] ?)[^\\s,;}]+", "$1**********")`,
```

**After (v2.0.0):**

```yaml
# Bearer/Basic/Digest/Token/API key (case-sensitive for Basic/Digest, requires separator)
`replace_pattern(body, "((?:(?i:bearer)|Basic|Digest) |(?i:token|apikey|api_key)\\x22? *[=:] *\\x22?)[A-Za-z0-9._~+/=-]{8,}", "$1**********")`,

# Password/secret assignment (handles quoted values, preserves quotes)
`replace_pattern(body, "(?i)((?:password|passwd|senha|secret|client_secret|access_token|refresh_token|private_key)\\x22? *[=:] *)(?:(\\x22)[^\\x22]*(\\x22)|[^\\s,;}]+)", "$1$2**********$3")`,
```

**What changed:**

1. **Basic and Digest are now case-sensitive** — prose like "basic validation failed" or "invalid token signature" will not be masked
2. **Token/API key fields require a separator** (`=` or `:`) — the word "token" in running text will not trigger masking
3. **Quoted values are masked up to the closing quote** — spaces inside the value are preserved, and both quotes remain visible

**Examples:**

| Log line | v1.0.0 | v2.0.0 |
|----------|--------|--------|
| `Authorization: Bearer abc123...` | Masked | Masked (unchanged) |
| `Authorization: Basic abc123...` | Masked | Masked (unchanged) |
| `invalid token signature` | Masked | **Stays in clear** |
| `basic validation failed` | Masked | **Stays in clear** |
| `password=secret123` | Masked | Masked (unchanged) |
| `{"password": "my secret 123"}` | Masked to `{"password": "my` | Masked to `{"password": "**********"}` |

> **Important:** The quoted-value handling prevents partial masking of JSON strings. In v1.0.0, a password with spaces would be masked only up to the first space, leaving the rest exposed.

---

## Configuration Reference

### Fleet Management

```yaml
fleetManagement:
  enabled: true  # Changed from false in v1.0.0
  url: "https://fleet.lerian.io"
  pollFrequency: "1m"
```

| Flag | Default (v1.0.0) | Default (v2.0.0) | Description |
|------|------------------|------------------|-------------|
| `enabled` | `false` | `true` | Enable remote configuration via Fleet Management |
| `url` | `https://fleet.lerian.io` | `https://fleet.lerian.io` | Fleet endpoint URL (unchanged) |
| `pollFrequency` | `1m` | `1m` | How often to poll for configuration updates (unchanged) |

**To disable Fleet Management:**

```yaml
fleetManagement:
  enabled: false
```

### Sanitization Rules

Sanitization rules are **not configurable** and are embedded in the chart templates. The v2.0.0 rules are applied automatically on upgrade.

**What is masked:**

- Full names (3+ words)
- Email addresses (local part only)
- Phone numbers (subscriber number only)
- Bank account and branch numbers
- Postal addresses (entire value)
- Pix keys (when labeled as `pixKey`, `pix_key`, `chave_pix`, or `chavePix`)
- Credentials (passwords, tokens, API keys, secrets)

**What stays in clear:**

- CPF (11-digit fiscal document)
- CNPJ (14-digit fiscal document)
- Matricula, contract numbers
- UUIDs (unless labeled as a Pix key)
- Resource identifiers (`acc_`, `txn_`, `cus_`, `ord_`)

> **Note:** The sanitization rules are verified against the pinned Alloy version (1.18.1). Upgrading the Alloy dependency requires re-running the sanitization gate.

---

## Preview changes before upgrading

```bash
helm diff upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.0 -n alloy-lerian
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade alloy-lerian oci://registry-1.docker.io/lerianstudio/alloy-lerian-helm --version 2.0.0 -n alloy-lerian
```
