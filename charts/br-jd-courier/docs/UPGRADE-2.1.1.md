<!-- {% raw %} -->
# Helm Upgrade from v2.1.0 to v2.1.1

## Topics

- **[Fixes](#fixes)**
  - [Application version update](#application-version-update)
  - [Readiness probe timeout adjustment](#readiness-probe-timeout-adjustment)
  - [Migration Job scheduling controls](#migration-job-scheduling-controls)
  - [Secret key validation expansion](#secret-key-validation-expansion)
  - [Documentation clarifications](#documentation-clarifications)

---

## Fixes

### Application version update

| Setting | v2.1.0 | v2.1.1 |
|---------|---------|---------|
| `appVersion` | `1.1.0` | `1.2.0` |
| `jd-courier.image.tag` | `1.1.0` | `1.2.0` |

**What changed:**

The chart now defaults to the `1.2.0` application release. Both the chart's `appVersion` (the fallback when `jd-courier.image.tag` is empty) and the explicit default tag in `values.yaml` have been updated.

**Why it matters:**

If you are using the default image tag (not overriding `jd-courier.image.tag` in your values), upgrading to v2.1.1 will deploy the `1.2.0` application image. Moving from Courier `1.1.x` to `1.2.0` is not a drop-in patch. The chart README documents these effects:

- **Schema.** The `pre-upgrade` migration Job runs `migrate up` before the rollout, and the `1.2.0` migrations drop schema that the running `1.1.x` pods still read (the engine credential column and the bypass table). Until the rollout replaces them, the old `spb-sender`, `pix-ingress` and `admin` pods fail every engine lookup: engine SOAP sends are refused and deliveries fail. The old `spb-consumer` stops reading from JD until it is replaced, and messages wait in JD's queue. Upgrade an install with an active channel in a quiet window.
- **Pix ingress credential.** Courier `1.2.0` removed `PIX_VENDOR_SUBJECTS` (multi-tenant: `jd-courier.pix/vendor_subjects`) and admits JD only as the client's partner in the Access Manager. From `1.1.x`, JD's current credential stops working at the rollout, and inbound Pix answers `401` to JD from the moment the client admin deletes JD's old applications until JD switches to the partner credential. Schedule the window with JD.
- **Single-tenant Access Manager keys.** The chart now turns on `IDP_DECLARATION_ENABLED`, which makes `IDP_HOST`, `IDP_M2M_CLIENT_ID` and `IDP_M2M_CLIENT_SECRET` mandatory. See [Documentation clarifications](#documentation-clarifications).

**Migration action:**

For an install running Courier `1.1.x`, follow the order in the chart README (sections "Migrations" and "Pix ingress (JD)"):

1. Record the subjects that `config.PIX_VENDOR_SUBJECTS` lists (JD's ordinary client applications), then remove the key from `config`: `1.2.0` no longer reads it.
2. Bring the Access Manager to `3.14.0` or later and Caradhras to `1.8.6` or later (or `1.9.0-beta.1` or later on the 1.9 line). Below that, the client admin cannot create JD's partner.
3. Right before the upgrade, the client admin deletes every application recorded in step 1. `1.2.0` admits a client application as admin on every operator route, so none may remain once the `1.2.0` grants are published.
4. Upgrade with the single-tenant [Access Manager](#documentation-clarifications) keys set.
5. Wait for `permission_declaration` in `/readyz` to read `up`.
6. The client admin creates JD's partner in the Console (one grant: `jd-courier` `pix-ingress` `post`) and issues JD's application under it. JD switches to that credential.

Multi-tenant installs set `migrations.enabled=false` and apply per-tenant migrations through the tenant manager; the chart refuses `migrations.enabled=true` together with `config.MULTI_TENANT_ENABLED=true`.

**If you want to stay on a specific version:**

Override the tag explicitly in your `values.yaml` before upgrading:

```yaml
jd-courier:
  image:
    tag: "1.1.0"  # Pin to previous version
```

> **Note:** With `helm upgrade --reuse-values`, Helm replaces the new chart's built-in defaults with the previous release's, so the tag stays `1.1.0` and `IDP_DECLARATION_ENABLED` is not added until you set them yourself. To take the new defaults and keep your own values, use `--reset-then-reuse-values` (Helm 3.14 or later).

> **Warning:** Pinning is not a rollback. Once the `1.2.0` migrations have run against the database, `1.1.x` pods fail because the schema they read is gone.

**If you are already overriding the tag:**

Your override will continue to take precedence. Review your `values.yaml` to ensure you're using the intended version:

```yaml
jd-courier:
  image:
    tag: "1.2.0"  # Explicitly use new release
```

> **Note:** Registry tags have no leading `v`. Always use `1.2.0`, not `v1.2.0`.

### Readiness probe timeout adjustment

**What changed:**

The readiness probe timeout has been increased from the Kubernetes default of 1 second to 3 seconds:

**Before (v2.1.0):**

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: http
  periodSeconds: 10
  # timeoutSeconds defaults to 1
```

**After (v2.1.1):**

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: http
  periodSeconds: 10
  # /readyz gives its database ping 2 s; the kubelet's default is 1 s.
  timeoutSeconds: 3
```

**Why it matters:**

The `/readyz` endpoint gives its database ping 2 seconds, while the kubelet's default probe timeout is 1 second. With `timeoutSeconds: 3`, the probe waits long enough for the full database ping to complete.

**Migration action:**

None required in your values. The probe change is applied automatically during upgrade.

> **Note:** This change affects all four roles (`spb-consumer`, `spb-sender`, `pix-ingress`, `admin`). The probe configuration is defined in the shared `_helpers.tpl` template.

> **Note:** All four Deployments roll during this upgrade: the probe and the image tag change the pod template, and the new `IDP_DECLARATION_ENABLED` key changes the ConfigMap checksum annotation (`checksum/config`), so even a pinned image tag does not avoid the rollout. `spb-consumer` uses the `Recreate` strategy (single writer), so its old pod stops before the new one starts. Every role has `terminationGracePeriodSeconds: 100`.

### Migration Job scheduling controls

**What changed:**

The database migration Job now respects the chart's top-level `nodeSelector`, `tolerations`, and `affinity` values:

**Before (v2.1.0):**

```yaml
# migrations-job.yaml (truncated)
spec:
  template:
    spec:
      containers:
        - name: migrate
          # ...
      # No nodeSelector, tolerations, or affinity
```

**After (v2.1.1):**

```yaml
# migrations-job.yaml (truncated)
spec:
  template:
    spec:
      containers:
        - name: migrate
          # ...
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

**Why it matters:**

Previously, the migration Job ignored the chart's scheduling constraints (`nodeSelector`, `tolerations`, `affinity`), even if you set them in your values. This could cause the migration Job to fail if:

- Your cluster requires specific node selectors (e.g., `workload-type: database`)
- Your database is only accessible from certain nodes
- You use taints to isolate workloads

Now the migration Job uses the same scheduling values as the application Deployments.

**Migration action:**

No action required if you are not using `nodeSelector`, `tolerations`, or `affinity`.

**If you are using scheduling constraints:**

The migration Job will now automatically use your existing values. Example values (illustrative):

```yaml
nodeSelector:
  workload-type: application

tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "jd-courier"
    effect: "NoSchedule"

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: topology.kubernetes.io/zone
              operator: In
              values:
                - us-east-1a
```

Before upgrading, confirm that the nodes these values select can run the Job and reach the database.

> **Important:** The Job runs on every upgrade (`pre-install,pre-upgrade` hook). If no node satisfies these constraints, the Job pod stays Pending and the Job fails once `migrations.activeDeadlineSeconds` (default `600`) passes. Adjust the constraints in that case.

### Secret key validation expansion

**What changed:**

The chart now refuses to render if `IDP_M2M_CLIENT_SECRET` or `M2M_CLIENT_SECRET` appear in the `config` block:

**Before (v2.1.0):**

```go
{{- $forbidden := list "COURIER_ROLES" "LICENSE_KEY" "DATABASE_URL" "POSTGRES_PASSWORD" "POSTGRES_REPLICA_PASSWORD" "REDIS_PASSWORD" "MULTI_TENANT_REDIS_PASSWORD" "MULTI_TENANT_SERVICE_API_KEY" "JD_PASSWORD" "JD_SPI_CLIENT_SECRET" "JD_PRIVATE_KEY_PEM" -}}
```

**After (v2.1.1):**

```go
{{- $forbidden := list "COURIER_ROLES" "LICENSE_KEY" "DATABASE_URL" "POSTGRES_PASSWORD" "POSTGRES_REPLICA_PASSWORD" "REDIS_PASSWORD" "MULTI_TENANT_REDIS_PASSWORD" "MULTI_TENANT_SERVICE_API_KEY" "JD_PASSWORD" "JD_SPI_CLIENT_SECRET" "JD_PRIVATE_KEY_PEM" "IDP_M2M_CLIENT_SECRET" "M2M_CLIENT_SECRET" -}}
```

**Why it matters:**

The chart enforces that all secret values must arrive through `secrets.existingSecret`, never through the `config` block (which renders into a ConfigMap visible to anyone with read access to the namespace).

Version 2.1.1 adds two additional secret keys to the validation list:

- `IDP_M2M_CLIENT_SECRET`: the secret of the Courier's M2M application in the Access Manager. Single-tenant only; every role reads it from the Secret.
- `M2M_CLIENT_SECRET`: lib-auth's deprecated alias.

If you were accidentally setting either of these in `config`, the chart will now refuse to render with the error `config.<KEY> is refused: secrets arrive through secrets.existingSecret, never as rendered values`.

**Migration action:**

**If you are not setting these keys:**

No action required.

**If you have `IDP_M2M_CLIENT_SECRET` or `M2M_CLIENT_SECRET` in your `config` block:**

1. Remove them from `config`:

```yaml
# Will now fail to render:
config:
  IDP_M2M_CLIENT_SECRET: "secret-value-here"  # Remove this
```

2. Add the value to the Secret that `secrets.existingSecret` names (or the default Secret, `<release fullname>`), changing only the new key. Do not re-create the Secret from placeholders: that would overwrite `LICENSE_KEY`, `DATABASE_URL` and `POSTGRES_PASSWORD`.

```bash
kubectl patch secret <secret-name> -n br-jd-courier --type merge \
  -p '{"stringData":{"IDP_M2M_CLIENT_SECRET":"<value>"}}'
```

3. Ensure `secrets.existingSecret` references that Secret (leave it empty to use the release fullname):

```yaml
secrets:
  existingSecret: "<secret-name>"
```

> **Warning:** If you upgrade with these keys still in `config`, Helm fails at render with the error above.

> **Security note:** A value that sat in `config` was readable in the ConfigMap. Rotate that credential after moving it.

### Documentation clarifications

**What changed:**

The `values.yaml` comments have been updated to clarify single-tenant secret requirements, and one new default key is rendered. The chart README also gained the Access Manager, Pix ingress (JD), AWS identity and Install sections.

**Before (v2.1.0):**

```yaml
secrets:
  # Name of the Secret loaded into every role (envFrom, and LICENSE_KEY by name
  # through secretKeyRef); defaults to the release fullname. It must exist
  # before install and carries LICENSE_KEY,
  # POSTGRES_PASSWORD and, for the migration Job, DATABASE_URL. The chart never
  # renders a Secret or a secret value.
  existingSecret: ""
```

**After (v2.1.1):**

```yaml
secrets:
  # Name of the Secret loaded into every role (envFrom, and LICENSE_KEY by name
  # through secretKeyRef); defaults to the release fullname. It must exist
  # before install and carries LICENSE_KEY, POSTGRES_PASSWORD, DATABASE_URL for
  # the migration Job and, single-tenant, IDP_M2M_CLIENT_SECRET and JD_PASSWORD.
  # The chart never renders a Secret or a secret value.
  existingSecret: ""
```

Additionally, the `config` block comments now mention single-tenant IDP requirements, and the `PIX_VENDOR_SUBJECTS` text is gone:

**Before (v2.1.0):**

```yaml
# Authentication is on, and every role then needs PLUGIN_AUTH_HOST (the Access
# Manager's address). ALLOW_AUTH_DISABLED_LOCAL_ONLY is refused: a chart install
# is never a developer's machine. The pix-ingress role also needs the Pix
# vendor's credential subject: PIX_VENDOR_SUBJECTS in single-tenant, or
# SYSTEMPLANE_ENABLED=true in multi-tenant, where each tenant's subjects live in
# systemplane jd-courier.pix/vendor_subjects; without it its pods refuse to boot.
```

**After (v2.1.1):**

```yaml
# Authentication is on, and every role then needs PLUGIN_AUTH_HOST (the Access
# Manager's address). ALLOW_AUTH_DISABLED_LOCAL_ONLY is refused: a chart install
# is never a developer's machine. Single-tenant also needs the IDP_* keys
# (README "Access Manager"); AWS_REGION: README "AWS identity".
```

And a **new rendered default**, not only a comment:

```yaml
config:
  PLUGIN_AUTH_ENABLED: "true"
  # Single-tenant publishes the Courier's grants at boot; multi-tenant ignores it.
  IDP_DECLARATION_ENABLED: "true"
```

`IDP_DECLARATION_ENABLED: "true"` now appears in the rendered ConfigMap; the v2.1.0 ConfigMap did not carry it.

**Why it matters:**

1. Single-tenant, the Courier publishes its own grants to the client's Access Manager at boot. With the flag on, a missing key refuses the boot and names it, so every role fails to start if the keys below are absent.
2. Until the Access Manager accepts the grants, a first install refuses every operator (`403`) and every engine and JD (`401`) while every pod reads Ready: `/readyz` answers `200` with `permission_declaration` `degraded`. A green rollout proves nothing here; wait for that entry to read `up`. Keep the flag on: off, nothing is declared.
3. Single-tenant deployments need `IDP_M2M_CLIENT_SECRET` and `JD_PASSWORD` in the Secret.
4. The `br-jd-courier.multiTenant` helper comment in `_helpers.tpl` now says the service accepts only the exact word `true` for `MULTI_TENANT_ENABLED`. The chart's own check is unchanged: it still refuses `migrations.enabled=true` when `config.MULTI_TENANT_ENABLED` is `1`, `t` or `true` in any case. The README adds that every Courier boolean under `config` is the exact word `true` or `false`; `1`, `t` or `TRUE` refuses the boot and every role crash-loops.

**Migration action:**

**For multi-tenant deployments:** `IDP_DECLARATION_ENABLED` is ignored, and you do not need the `IDP_*` keys, `IDP_M2M_CLIENT_SECRET` or `JD_PASSWORD`. The RI catalog and the tenant manager's reconcile carry the grants.

**For single-tenant deployments:** before upgrading, set these keys.

| Key | Where | Value |
|---|---|---|
| `IDP_HOST` | `config` | the Access Manager identity address (port `4001`, not `PLUGIN_AUTH_HOST`), e.g. `http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001` |
| `IDP_M2M_CLIENT_ID` | `config` | the Courier's M2M application |
| `IDP_M2M_CLIENT_SECRET` | the Secret | that application's secret; refused under `config` |

```yaml
config:
  PLUGIN_AUTH_HOST: "<Access Manager address>"
  IDP_HOST: "http://plugin-access-manager-identity.<namespace>.svc.cluster.local:4001"
  IDP_M2M_CLIENT_ID: "<Courier M2M application client id>"
```

```bash
kubectl patch secret <secret-name> -n br-jd-courier --type merge \
  -p '{"stringData":{"IDP_M2M_CLIENT_SECRET":"<value>","JD_PASSWORD":"<value>"}}'
```

Nothing provisions the M2M application: the install's admin issues it once, as a person, with `POST /v1/applications/service-credentials`, `source` `jd-courier` and `target` `plugin-identity` (Access Manager `3.13.0` or later). Only the create answer shows the `clientSecret`. If a refused credential or manifest logs an ERROR and leaves the entry `degraded`, fix it and run `kubectl rollout restart` on the Deployments.

Also documented in the README, no values change required: `AWS_REGION` is the only source of the Secrets Manager region (default `us-east-1`; on EKS, IRSA or Pod Identity inject the cluster's region, which wins over `config`), and `config.JD_SPI_USE_SERVICE_SEGMENTS: "true"` must equal the Pix engine's `JD_USE_SERVICE_SEGMENTS` where JD's gateway fronts the SPI cabin and the Pix transit is enabled.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.1.1 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

> **Note:** An anonymous pull from `registry-1.docker.io` is refused with `401`. Without Docker Hub access, use the GHCR reference `oci://ghcr.io/lerianstudio/br-jd-courier-helm` in both commands.

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.1.1 -n br-jd-courier
```
<!-- {% endraw %} -->
