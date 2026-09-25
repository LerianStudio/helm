# Helm Upgrade from v4.0.0 to v4.1.0

# Topics

- **[Overview](#overview)**
- **[Features](#features)**
  - [1. `secrets.DATASOURCE_CRED_ENC_KEY` is now a first-class chart parameter](#1-secretsdatasource_cred_enc_key-is-now-a-first-class-chart-parameter)
  - [2. `manager.configmap.TRUSTED_PROXIES` is now an explicit chart parameter](#2-managerconfigmaptrusted_proxies-is-now-an-explicit-chart-parameter)
- **[Configuration Reference](#configuration-reference)**
- **[Known Gotchas (Field-Verified)](#known-gotchas-field-verified)**
- **[Migration Guide](#migration-guide)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Overview

**Nothing in this chart release changes for an install that stays on reporter app 2.4.x.** The chart's `appVersion` is unchanged and the new key is empty by default, so a plain `helm upgrade` is a no-op for existing 2.4.x releases.

Everything below is about **preparing for reporter app 3.x**, which carries two behaviour changes an operator must configure for before pinning a `3.x` image tag. Both were already reachable through the chart's generic passthrough (`secrets` renders every key it is given; `manager.configmap` accepts any allowlisted key) — this release makes them documented, defaulted, and fail-fast instead of tribal knowledge.

# Features

### 1. `secrets.DATASOURCE_CRED_ENC_KEY` is now a first-class chart parameter

Reporter app **3.0.0 and later stores registered data-source credentials encrypted at rest**. Both the manager and the worker read a single symmetric key from `DATASOURCE_CRED_ENC_KEY` and **refuse to boot** when it is unset. A request that needs the key while it is unconfigured fails with error code **`RPT-0074`**.

**What operators need to do (before pinning an app 3.x image tag):**

```bash
openssl rand -hex 32
```

```yaml
secrets:
  # 64 hex characters from the command above
  DATASOURCE_CRED_ENC_KEY: "3f7a...c19b"
```

| Property | Value |
|----------|-------|
| Format | Hex-encoded AES key — **32, 48 or 64 hex characters** (16, 24 or 32 bytes) |
| Generate | `openssl rand -hex 32` |
| Scope | **One value shared by the manager and the worker** — they encrypt and decrypt the same records |
| Rotation | **None in this release.** Changing the value makes every already-registered data source undecryptable |
| Required from | reporter app `3.0.0` |
| Ignored by | reporter app `2.4.x` (this chart's default `appVersion`) |

**Where the chart enforces it:**

The manager and worker Secret templates now fail the render when **that component's** resolved image tag parses as semver and is `>= 3.0.0` while the key is empty:

```
ERROR: secrets.DATASOURCE_CRED_ENC_KEY is REQUIRED for reporter app >= 3.0.0 (manager.image.tag is "3.0.0-beta.1").
   The app encrypts data-source credentials at rest and will NOT boot without it.
   Generate once: openssl rand -hex 32
   Use the SAME value for the manager and the worker. There is NO rotation — changing it
   makes every already-registered data source undecryptable.
```

Two further checks run regardless of image tag, because neither input can ever be a correct value:

- a value of `CHANGE_ME` (the `values-template.yaml` placeholder) is rejected;
- a value that is not 32/48/64 hex characters is rejected.

A **floating tag** (`latest`, a digest, anything that does not parse as semver) is left alone — the chart will not guess an app version, so with a floating tag the key is your responsibility.

**`useExistingSecret` path:** the guard is inside the chart-managed Secret template, so an install with `manager.useExistingSecret: true` / `worker.useExistingSecret: true` is not checked. Add `DATASOURCE_CRED_ENC_KEY` to your externally-managed Secret yourself — with the same value in the manager's and the worker's Secret.

### 2. `manager.configmap.TRUSTED_PROXIES` is now an explicit chart parameter

Reporter app 3.x ships **lib-auth v3.4.0**, which derives the caller's client IP **exclusively** from the proxy list in `TRUSTED_PROXIES`. There is no fallback to the socket peer address.

**Why this matters:** with `TRUSTED_PROXIES` empty, **no client IP is forwarded at all**. Any tenant configured with an IP allowlist then sees an empty client IP and **denies every request**. Tenants without an IP allowlist are unaffected.

The key already validated through the chart's configmap allowlist; it now ships with an explicit empty default and this documentation:

```yaml
manager:
  configmap:
    # the ingress / load-balancer addresses actually in front of the manager
    TRUSTED_PROXIES: "10.0.0.0/8,172.16.0.0/12"
```

Set it to the addresses of the proxies that genuinely front this service — not to a blanket `0.0.0.0/0`, which lets any caller spoof its own client IP through `X-Forwarded-For` and makes the allowlist meaningless.

# Configuration Reference

```yaml
manager:
  image:
    tag: "3.0.0-beta.1"      # pinning >= 3.0.0 activates the key requirement below
  configmap:
    TRUSTED_PROXIES: ""      # empty = no client IP forwarded (app 3.x / lib-auth v3.4.0)

worker:
  image:
    tag: "3.0.0-beta.1"      # must match the manager's app major

secrets:
  DATASOURCE_CRED_ENC_KEY: ""   # hex AES key, 32/48/64 chars; identical on both components
```

# Known Gotchas (Field-Verified)

### The key must be identical on the manager and the worker

Both components are wired from the same `secrets` map, so the chart-managed path gives them the same value automatically. The way to break this is to split them: `manager.useExistingSecret` / `worker.useExistingSecret` pointing at two different Secrets, or two separate releases. The manager encrypts the credential the operator registers; the worker decrypts it when it runs the report. A mismatch is silent at deploy time and surfaces later as report generation failing to read its own data sources.

### There is no rotation — treat the key as permanent

Changing `DATASOURCE_CRED_ENC_KEY` does not re-encrypt anything. Every data source registered under the old key becomes undecryptable and has to be registered again. Store the value in your secret manager the same way you already store `secrets.RABBITMQ_ERLANG_COOKIE`, which has the same "generate once, never change" property.

### Put the key in `secrets`, not in `common.configmap`

The chart's configmap escape hatch accepts any key matching `DATASOURCE_[A-Z0-9_]+`, so `common.configmap.DATASOURCE_CRED_ENC_KEY` is accepted by schema validation and renders into a **plaintext ConfigMap** with no warning. The app would read it and work, which is what makes the mistake easy to miss. It belongs under `secrets:`.

### Roll the manager and worker together

The key is required by both components independently. Upgrading one to `3.x` while the other stays on `2.4.x` renders (each component's gate reads its own tag) but leaves a split-version deployment where only one side encrypts. Pin both image tags in the same upgrade.

# Migration Guide

Staying on reporter app 2.4.x: nothing to do.

Moving to reporter app 3.x:

1. Generate the key once: `openssl rand -hex 32`. Store it in your secret manager.
2. Set `secrets.DATASOURCE_CRED_ENC_KEY` to that value (or add the key to your existing Secret, for both the manager and the worker, when using `useExistingSecret`).
3. Set `manager.configmap.TRUSTED_PROXIES` to the ingress / load-balancer addresses in front of the manager, if any tenant uses an IP allowlist.
4. Pin **both** `manager.image.tag` and `worker.image.tag` to the same app 3.x version.
5. Render before applying (`helm diff upgrade` below) and confirm the render succeeds — a missing key fails there rather than in a CrashLoopBackOff.

# Preview changes before upgrading

> **Important:** Pass your values file (`-f values.yaml`) or `--reuse-values` explicitly on every command below. A plain `helm upgrade`/`helm diff upgrade` with no values source falls back to the chart's bare defaults, not your existing release's values — this would revert any customization (datastores, secrets, replica counts, ...) already in place.

```bash
helm diff upgrade reporter oci://ghcr.io/lerianstudio/reporter-helm --version 4.1.0 -n reporter -f values.yaml
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade reporter oci://ghcr.io/lerianstudio/reporter-helm --version 4.1.0 -n reporter -f values.yaml
```
