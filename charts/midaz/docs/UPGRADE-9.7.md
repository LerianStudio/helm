# Helm Upgrade from v9.6.x to v9.7.0

## Topics

- **[Breaking: standalone CRM KMS default](#1-standalone-crm-kms_vendor-now-defaults-to-none)**
- **[Fixes](#fixes)**
  - [2. RabbitMQ Erlang cookie is required at render](#2-rabbitmq-erlang-cookie-is-required-at-render)
  - [3. Tracer migrations run as a regular Job on a plain Helm install](#3-tracer-migrations-run-as-a-regular-job-on-a-plain-helm-install)
  - [4. Ledger refuses to render with ENV_NAME=production and auth off](#4-ledger-refuses-to-render-with-env_nameproduction-and-auth-off)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

### 1. Standalone CRM `KMS_VENDOR` now defaults to `none`

**Who is affected:** only a deployment that runs the standalone CRM (`crm.enabled: true`), does **not** set `crm.configmap.KMS_VENDOR`, and runs its own Vault reachable as `midaz-hc-vault:8200`. Every other deployment is unaffected; one that already sets `KMS_VENDOR` keeps its value.

#### What changed

| Key | v9.6.x default | v9.7.0 default |
|-----|----------------|----------------|
| `crm.configmap.KMS_VENDOR` | `hashicorp-vault` | `none` (legacy mode, `crm.secrets.LCRYPTO_*` keys), same as the ledger |
| `crm.configmap.KMS_VAULT_ADDR` | `http://midaz-hc-vault:8200` | none: required when `KMS_VENDOR` is `hashicorp-vault` |

The chart bundles no Vault, so the old default pointed the CRM at a host that does not exist and the CRM never became Ready.

#### Why it matters

A deployment that relied on the old default with its own Vault at `midaz-hc-vault` would switch from envelope encryption to legacy mode on upgrade. Holder fields already written with envelope encryption could stop decrypting.

#### Action required

If you use Vault envelope encryption for the CRM, set both values explicitly before upgrading:

```yaml
crm:
  configmap:
    KMS_VENDOR: "hashicorp-vault"
    KMS_VAULT_ADDR: "http://midaz-hc-vault:8200"   # your Vault address
    KMS_VAULT_AUTH_METHOD: "token"                 # unchanged default; set yours if different
```

With `KMS_VENDOR: "hashicorp-vault"` and no `KMS_VAULT_ADDR`, the render now fails with `crm.configmap.KMS_VAULT_ADDR is required when KMS_VENDOR=hashicorp-vault`.

## Fixes

### 2. RabbitMQ Erlang cookie is required at render

`rabbitmq.authentication.erlangCookie.value` defaults to `""`, and the bundled broker refuses to boot on an empty cookie (`Too short cookie string`). The chart now refuses to render the bundled RabbitMQ without a cookie.

#### Action required

None if your values already set the cookie. Otherwise set a stable value (it must not change across upgrades):

```yaml
rabbitmq:
  authentication:
    erlangCookie:
      value: "<openssl rand -hex 32>"
```

Alternatively, use `rabbitmq.authentication.existingSecret` + `rabbitmq.authentication.erlangCookie.secretKey`, an `ERLANG_COOKIE` entry in `rabbitmq.env`, or `rabbitmq.extraEnvSecrets`.

### 3. Tracer migrations run as a regular Job on a plain Helm install

The tracer migration Job was a `post-install,pre-upgrade` Helm hook. `helm install --wait` runs post-install hooks only after every workload is Ready, and the tracer cannot become Ready before its schema exists, so the install never finished.

On `helm install` the Job is now a regular release resource, created together with PostgreSQL; the tracer becomes Ready once it has run. On `helm upgrade` it stays a `pre-upgrade` hook: the new tracer rolls out only after the migration completes, and a failed migration fails the upgrade. The Job is named `midaz-tracer-migrations-<tag>-<hash>`, so any spec change creates a new Job. The ArgoCD `Sync` hook annotations are unchanged.

#### Action required

None.

### 4. Ledger refuses to render with `ENV_NAME=production` and auth off

Since 4.0.0 the ledger refuses to boot when `ENV_NAME=production` and `PLUGIN_AUTH_ENABLED` is not `true`, and those were the chart defaults, so such a release deployed a ledger that crash-looped. The chart now applies the same rule at render: an install or upgrade with a 4.x ledger image, `ENV_NAME=production` and auth off fails with:

```
ledger: ENV_NAME=production requires PLUGIN_AUTH_ENABLED=true ...
```

#### Action required

Production, with the Access Manager:

```yaml
ledger:
  configmap:
    PLUGIN_AUTH_ENABLED: "true"   # or global.auth.enabled: true
```

Non-production environments without the Access Manager:

```yaml
ledger:
  configmap:
    ENV_NAME: "staging"           # or global.env.name; any value other than production
```

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.7.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.7.0 -n midaz
```
