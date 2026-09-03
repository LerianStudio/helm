# Helm Upgrade from v4.2.0 to v4.3.0

## Topics

- **[Overview](#overview)**
- **[Breaking Changes](#breaking-changes)**
  - [1. The RabbitMQ bootstrap Job is now topology-only](#1-the-rabbitmq-bootstrap-job-is-now-topology-only)
  - [2. `externalRabbitmqDefinitions.appCredentials` was removed](#2-externalrabbitmqdefinitionsappcredentials-was-removed)
  - [3. The Job's management-API credential moved to a PreSync Secret](#3-the-jobs-management-api-credential-moved-to-a-presync-secret)
- **[Features](#features)**
  - [4. TLS verification is now on by default on the management API calls](#4-tls-verification-is-now-on-by-default-on-the-management-api-calls)
  - [5. The Job no longer installs packages at runtime](#5-the-job-no-longer-installs-packages-at-runtime)
- **[Configuration Changes](#configuration-changes)**
- **[Who is affected](#who-is-affected)**
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Overview

This release narrows the scope of the external RabbitMQ bootstrap Job (`externalRabbitmqDefinitions.enabled: true`) to **messaging topology only**. The Job applies exchanges, queues and bindings inside the default vhost `/` and nothing else. Creating the application broker user and granting its permissions is no longer the chart's job, and the values keys that configured that user were removed.

If you do not enable `externalRabbitmqDefinitions` (the chart default is `false`, and it is off in every Lerian-operated tier), nothing in this release affects you.

| Field | v4.2.0 | v4.3.0 |
|-------|--------|--------|
| Chart version | `4.2.0` | `4.3.0` |
| Bootstrap Job scope | exchanges, queues, bindings, **app user, app permissions** | exchanges, queues, bindings |
| `externalRabbitmqDefinitions.appCredentials.*` | present | **removed** (render fails if set) |
| `externalRabbitmqDefinitions.connection.skipTlsVerify` | — (verification always skipped) | new key, default `false` |
| Job's management-API credential | inline `value:` in the Job env, or `secretKeyRef` into `useExistingSecret.name` | always `secretKeyRef`; a chart-emitted `PreSync` Secret carries it |
| Default credential identity | `rabbitmqAdminLogin.username`, defaulting to `midaz` | the application's broker user, `secrets.RABBITMQ_DEFAULT_USER` |
| `externalRabbitmqDefinitions.rabbitmqAdminLogin.username` | `"midaz"` | `""` — optional override, both halves or neither |

## Breaking Changes

### 1. The RabbitMQ bootstrap Job is now topology-only

**What changed:**

The Job previously issued two additional management API calls: `PUT /api/users/reporter`, which created (or reset the password of) the `reporter` broker user, and `PUT /api/permissions/%2F/reporter`, which granted that user configure/write/read permissions on the default vhost. Both calls are gone, along with the `RABBITMQ_APP_PASS` environment variable that fed them.

What remains is topology: one management API call per exchange, queue and binding declared in the chart's definitions file, all inside the default vhost `/`.

**Why this matters:**

The Job holds the broker's **admin** credential. Using it to mint the application's own identity meant the chart decided who the app is and what it may do on the broker — a decision that belongs to whoever operates the broker, not to a workload chart. Vhost creation and tenant vhost topology were already outside this Job's remit; user and permission provisioning now follow.

**What operators need to do:**

Provision the application broker user on the broker itself, outside this chart, before enabling the Job. The user must be the one configured in `secrets.RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` (or supplied through your existing-secret setup), and it needs configure/write/read permissions on the default vhost `/`.

### 2. `externalRabbitmqDefinitions.appCredentials` was removed

**What changed:**

| Setting | v4.2.0 | v4.3.0 |
|---------|--------|--------|
| `externalRabbitmqDefinitions.appCredentials.reporterPassword` | password for the Job-created `reporter` user | **removed** |
| `externalRabbitmqDefinitions.appCredentials.useExistingSecret.name` | secret holding `RABBITMQ_DEFAULT_PASS` for that user | **removed** |

**Why this matters:**

With the user-creation calls gone, these keys had no consumer. Left in place they would have been **accepted and silently ignored** — the chart's schema allows unknown keys, so an operator could keep setting `reporterPassword`, see a clean upgrade, and assume the `reporter` user had been provisioned when nothing had created it.

Rather than deprecate the keys quietly, setting either of them now **fails the render** with an error naming the removed key and pointing to this document. A loud failure at `helm template`/`helm upgrade` time is the intended behaviour, not a bug.

**What operators need to do:**

```yaml
# Before (v4.2.0)
externalRabbitmqDefinitions:
  enabled: true
  rabbitmqAdminLogin:
    username: "admin"
    password: "REPLACE_ME"
  appCredentials:
    reporterPassword: "REPLACE_ME"

# After (v4.3.0) — remove the appCredentials block entirely
externalRabbitmqDefinitions:
  enabled: true
  rabbitmqAdminLogin:
    username: "admin"
    password: "REPLACE_ME"
```

The application's own broker credential is unchanged and still comes from `secrets.RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` (or your existing secret). Only the keys that told the *Job* to create that user were removed.

### 3. The Job's management-API credential moved to a PreSync Secret

The bootstrap Job authenticates to the RabbitMQ management API. In v4.2.0 it got that credential one of two ways: `secretKeyRef` into `rabbitmqAdminLogin.useExistingSecret.name` when that was set, and otherwise an **inline `value:`** built from `rabbitmqAdminLogin.username` / `.password`.

The inline path is the defect. On a tier that resolves secret references at render time (`<path:secret/...>` and similar), the resolved password is written into the Job manifest — where it is readable by anyone with pod-read in the namespace, in `helm get manifest`, and in the ArgoCD live view.

**In v4.3.0 the Job always reads both values through `secretKeyRef`.** There is no inline branch. When `useExistingSecret.name` is empty, the chart emits its own carrier:

| | |
|---|---|
| Kind / name | `Secret/reporter-bootstrap-rabbitmq` (same name as the Job; different kinds do not collide) |
| Keys | `RABBITMQ_ADMIN_USER`, `RABBITMQ_ADMIN_PASS` (fixed; the Job's env names are unchanged) |
| ArgoCD | `hook: PreSync`, `hook-weight: "-2"`, `hook-delete-policy: BeforeHookCreation` |
| Helm | `hook: pre-install,pre-upgrade`, `hook-weight: "-2"`, `hook-delete-policy: before-hook-creation` |

Weight `-2` puts the carrier one step ahead of the Job at `-1`, following the `br-sisbajud` migrations precedent. It has to be its own hook: the application's Secrets (`reporter-manager`, `reporter-worker`) carry only Helm hook annotations, so under ArgoCD they are **Sync**-phase and do not exist yet while a `PreSync` hook runs. The delete policy is `BeforeHookCreation` **only** — `HookSucceeded` would remove the carrier while the Job can still be retrying.

**The default credential is now the application's own broker credential** — `secrets.RABBITMQ_DEFAULT_USER` and `secrets.RABBITMQ_DEFAULT_PASS`, the values the reporter workloads already authenticate with. A tier that enables the Job therefore declares nothing beyond `enabled: true` and `connection.*`.

`rabbitmqAdminLogin` becomes an **optional override**, with three shapes and no fourth:

| Configuration | Result |
|---|---|
| nothing set (default) | carrier holds `secrets.RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` |
| `username` **and** `password` set | carrier holds those instead |
| `useExistingSecret.name` set | no carrier is emitted; the Job reads your Secret, which must have the two keys above |
| `useExistingSecret.name` **and** `username`/`password` | **render fails** — two credentials, no rule to choose between them (v4.2.0 silently preferred the external Secret) |
| only one of `username` / `password` | **render fails** — see below |

#### What breaks

1. **`rabbitmqAdminLogin.username` no longer defaults to `midaz`.** If you set only `password` and relied on that default, the Job used to authenticate as `midaz`. It now authenticates as your application's broker user — a different identity.
2. **A half-declared override fails the render.** Because `username` used to have a default, `password`-only was a *working* v4.2.0 configuration; in v4.3.0 it is a render error. This is deliberate: the alternative is pairing a foreign password with the application's username, which reaches the broker as a `401` during `PreSync` — a failed hook that blocks the whole sync and is diagnosed from a curl status code. The error names both keys and what to do.

   ```text
   Error: execution error at (reporter-helm/templates/common/bootstrap-rabbitmq.yaml): externalRabbitmqDefinitions.rabbitmqAdminLogin is half-declared (username="", password is set): an override must set BOTH, otherwise one half would silently be paired with the application's credential and reach the broker as a 401 during PreSync — set both username and password to override, or clear both to use the application's broker credential (secrets.RABBITMQ_DEFAULT_USER / RABBITMQ_DEFAULT_PASS)
   ```

   Fix it by setting both, or — more likely what you want — by removing the block entirely and letting the Job use the application credential.

#### What this does and does not hide

The credential no longer appears **in the Job manifest**, in any configuration. It is not hidden from the release manifest altogether: a chart-templated Secret's `stringData` is rendered like any other value, exactly as the other Secrets this chart emits. What changes is that the value lives in a `Secret` — RBAC-gated, absent from the pod spec and from `kubectl describe pod` — and that it is the **same** credential already stored in the `reporter-manager` Secret, so the carrier adds no new exposure. If you need the value never to be templated at all, use `useExistingSecret.name`.

#### Check what you have, before upgrading

```bash
helm get values reporter -n <namespace> -o yaml \
  | yq '.externalRabbitmqDefinitions.rabbitmqAdminLogin'
```

`null` — nothing to do. A `password` with no `username` — this is the configuration that now fails; remove the block or set both.

Then render the chart against your own values to see the two documents and confirm the render passes:

```bash
helm template reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.0 \
  -n <namespace> -f <your-values>.yaml \
  --show-only templates/common/bootstrap-rabbitmq.yaml
```

Expect `kind: Secret` at hook weight `-2` followed by `kind: Job` at `-1` — or, with `useExistingSecret.name` set, the Job alone.

#### Confirm it after upgrading

```bash
kubectl get job reporter-bootstrap-rabbitmq -n <namespace> -o json \
  | jq -r '.spec.template.spec.containers[]
           | select(.name=="apply-definitions").env[]
           | select(.name | test("ADMIN"))
           | "\(.name)\t\(if .value then "INLINE VALUE - unexpected" else "secretKeyRef \(.valueFrom.secretKeyRef.name)/\(.valueFrom.secretKeyRef.key)" end)"'
```

Both lines must read `secretKeyRef`. Against a v4.2.0 Job the same command prints `INLINE VALUE - unexpected` for both, which is what this change removes.

## Features

### 4. TLS verification is now on by default on the management API calls

The Job's management API calls previously ran `curl -k` unconditionally, which skipped TLS certificate verification even when `connection.protocol` was `https` — on an unverified channel that carried the broker's admin credential.

Verification is now conditional on a new key, `externalRabbitmqDefinitions.connection.skipTlsVerify`, which defaults to `false` (verify). For a broker presenting a self-signed or otherwise unverifiable certificate, opt out explicitly:

```yaml
externalRabbitmqDefinitions:
  connection:
    protocol: "https"
    skipTlsVerify: true
```

> **Note:** If you use the Job against an `https` broker whose certificate is not trusted by the job pod's CA bundle, the calls will now fail where they previously succeeded. Either make the CA trusted or set `skipTlsVerify: true` deliberately.

`connection.protocol` is also now constrained by the values schema to `http` or `https`; any other string is rejected at render time instead of being passed through into a URL.

### 5. The Job no longer installs packages at runtime

The Job previously ran `apk add jq` on startup to parse the definitions file. Parsing now happens at render time in Helm, so the job pod no longer needs network egress to Alpine package repositories to succeed. Clusters with restricted egress that had to allowlist those repositories for this Job no longer need to.

## Configuration Changes

| Setting | v4.2.0 | v4.3.0 | Notes |
|---------|--------|--------|-------|
| `externalRabbitmqDefinitions.appCredentials` | object | **removed** | Setting it fails the render |
| `externalRabbitmqDefinitions.appCredentials.reporterPassword` | `""` | **removed** | Provision the broker user outside the chart |
| `externalRabbitmqDefinitions.appCredentials.useExistingSecret.name` | `""` | **removed** | Provision the broker user outside the chart |
| `externalRabbitmqDefinitions.connection.skipTlsVerify` | — | `false` | New; `false` means verify TLS |
| `externalRabbitmqDefinitions.connection.protocol` | any string | `http` \| `https` | Now schema-constrained |
| `externalRabbitmqDefinitions.rabbitmqAdminLogin.username` | `"midaz"` | `""` | Empty means: use `secrets.RABBITMQ_DEFAULT_USER`. Set together with `password` to override; one alone fails the render |
| `externalRabbitmqDefinitions.rabbitmqAdminLogin.password` | `""` | `""` | Unchanged default; now never rendered as an inline `value:`, and must be paired with `username` |
| `externalRabbitmqDefinitions.rabbitmqAdminLogin.useExistingSecret.name` | `""` | `""` | Unchanged, and now mutually exclusive with `username`/`password` instead of silently winning |

No values keys were added, removed or renamed beyond the `appCredentials` removal in item 2; item 3 changes one default and adds two render-time checks.

## Who is affected

This section is deliberately explicit about what was measured and what was not.

**Measured — Lerian-operated tiers are not affected.** Across the 12 reporter tier values files in the Lerian gitops repositories, `externalRabbitmqDefinitions` does not appear in any of them, so the Job runs in **0 of 12** tiers (the chart default is `false`). Separately, on the user those tiers authenticate as: 9 of the 12 files set `RABBITMQ_DEFAULT_USER: plugin`, 1 sets `reporter` explicitly, and 2 leave the key unset and therefore fall back to the chart default, which is `reporter`. So **3 of 12** tiers would use the user the Job used to create, and 9 would not — but the Job is enabled in **none** of the 12, so no tier depended on it having created that user.

**Not measured — client single-tenant installations.** Those installations do not live in Lerian's gitops repositories, so their values were not inspected and their configuration is unknown here. An installation that both enabled `externalRabbitmqDefinitions` **and** relied on the Job to create the broker user it authenticates as will find that user is no longer provisioned by the upgrade. That case is the reason this document exists. It is not a known breakage — it is an unverified one, and it must be checked per installation before upgrading.

## Migration Steps

1. Check whether the Job is enabled at all:

   ```bash
   helm get values reporter -n <namespace> | grep -A5 externalRabbitmqDefinitions
   ```

   No output, or `enabled: false` — steps 2 to 5 do not apply; go to step 6.

2. Confirm the application's broker user exists on the broker independently of the chart, with permissions on the default vhost `/`:

   The management API endpoint is not fixed by the chart: build it from
   `externalRabbitmqDefinitions.connection.protocol`, `.host` and `.port` — the same
   values the Job uses. Keep the admin password out of the command line, where it
   would land in your shell history and in `/proc` for anyone on the host; put it in
   a `netrc` file readable only by you.

   ```bash
   # Paste the whole block. It runs in a subshell, so `set -e` cannot leave your
   # shell in a strict mode and the credential is removed when the block ends —
   # including when a call fails. Replace the values; do not run them as-is.
   (
     set -euo pipefail

     PROTOCOL=https                      # connection.protocol
     HOST=rabbitmq.example.internal      # connection.host
     PORT=15672                          # connection.port
     SKIP_TLS_VERIFY=false               # connection.skipTlsVerify
     ADMIN_USER=admin                    # rabbitmqAdminLogin.username, or
                                         # secrets.RABBITMQ_DEFAULT_USER when that
                                         # block is empty (the v4.3.0 default)
     APP_USER=reporter                   # secrets.RABBITMQ_DEFAULT_USER

     # Match the Job's TLS behaviour: verification is on unless you turned it off
     CURL_OPTS="-sS"
     if [ "$PROTOCOL" = "https" ] && [ "$SKIP_TLS_VERIFY" = "true" ]; then
       CURL_OPTS="$CURL_OPTS -k"
     fi

     # Arm the cleanup before the credential exists, so a failing call cannot
     # leave the password on disk
     umask 077                           # 0600 — not readable by other users
     NETRC=$(mktemp)
     trap 'rm -f "$NETRC"' EXIT

     read -rsp 'admin password: ' ADMIN_PASS; echo
     printf 'machine %s login %s password %s\n' "$HOST" "$ADMIN_USER" "$ADMIN_PASS" > "$NETRC"
     unset ADMIN_PASS

     # curl exits 0 on 4xx and 5xx, so the status has to be read and decided on:
     # otherwise a 401 from the broker reads exactly like a user that exists.
     check() {
       local label=$1 url=$2 code
       code=$(curl $CURL_OPTS -o /dev/null -w '%{http_code}' --netrc-file "$NETRC" "$url" || true)
       case "${code:-000}" in
         2??) echo "$label: present ($code)" ;;
         404) echo "$label: MISSING (404) — create it on the broker before upgrading" ;;
         *)   echo "$label: unexpected response (${code:-no response}) — check the endpoint and the admin credential" >&2
              return 1 ;;
       esac
     }

     check "user ${APP_USER}"        "${PROTOCOL}://${HOST}:${PORT}/api/users/${APP_USER}"
     check "permissions on / for ${APP_USER}" "${PROTOCOL}://${HOST}:${PORT}/api/permissions/%2F/${APP_USER}"
   )
   ```

   If `connection.protocol` is `https` and you have **not** set `skipTlsVerify`, the
   calls verify the broker's certificate — the same as the Job. A verification
   failure here is the same failure the Job would hit, so fixing the CA trust now
   fixes both.

   If either returns `404`, create the user and grant its permissions on the broker **before** upgrading — the chart will no longer do it.

3. Remove the `appCredentials` block from your values. Leaving it in place fails the render.

4. Reconcile `rabbitmqAdminLogin` (see [item 3](#3-the-jobs-management-api-credential-moved-to-a-presync-secret)): if it sets only `password`, either remove the whole block — the Job then uses `secrets.RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` — or add the matching `username`. Leaving one half set fails the render.

5. If `connection.protocol` is `https`, decide on TLS verification: either ensure the job pod trusts the broker's CA (recommended, and now the default), or set `connection.skipTlsVerify: true` explicitly.

6. Preview the changes with the helm-diff plugin (see [Preview changes before upgrading](#preview-changes-before-upgrading)).

7. Run the upgrade, then confirm the Job completed:

   ```bash
   kubectl get jobs -n <namespace> -l app.kubernetes.io/name=reporter
   kubectl logs -n <namespace> job/<bootstrap-job-name>
   ```

8. Confirm the application still connects to the broker:

   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-manager --tail=50
   kubectl logs -n <namespace> -l app.kubernetes.io/name=reporter-worker --tail=50
   ```

   Authentication failures here point at step 2 — the broker user, not the topology.

## Preview changes before upgrading

```bash
helm diff upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.0 -n <namespace>
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade reporter oci://registry-1.docker.io/lerianstudio/reporter-helm --version 4.3.0 -n <namespace>
```
