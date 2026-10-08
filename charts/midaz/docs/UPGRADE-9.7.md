# Helm Upgrade from v9.6.x to v9.7.0

## Topics

- **[Breaking: standalone CRM KMS default](#1-standalone-crm-kms_vendor-now-defaults-to-none)**
- **[Fixes](#fixes)**
  - [2. RabbitMQ Erlang cookie is required at render](#2-rabbitmq-erlang-cookie-is-required-at-render)
  - [3. Tracer migrations run as a regular Job under plain Helm](#3-tracer-migrations-run-as-a-regular-job-under-plain-helm)
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

### 3. Tracer migrations run as a regular Job under plain Helm

The tracer migration Job was a `post-install,pre-upgrade` Helm hook. `helm install --wait` runs post-install hooks only after every workload is Ready, and the tracer cannot become Ready before its schema exists, so the install never finished.

Under plain Helm the Job is now a regular release resource named `midaz-tracer-migrations-<tag>-<spec hash>`; any change to its spec creates a new Job. The ArgoCD `Sync` hook annotations are unchanged.

#### Operational impact

On `helm upgrade`, new tracer pods may restart until the Job has migrated the schema, while the previous ReplicaSet keeps serving. No action is required.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.7.0 -n midaz
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm --version 9.7.0 -n midaz
```
