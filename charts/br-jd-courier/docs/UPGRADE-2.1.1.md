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

If you are using the default image tag (not overriding `jd-courier.image.tag` in your values), upgrading to v2.1.1 will deploy the `1.2.0` application image. This version includes application-level improvements and fixes.

**Migration action:**

No action required for most operators. The upgrade will automatically pull the `1.2.0` image.

**If you want to stay on a specific version:**

Override the tag explicitly in your `values.yaml`:

```yaml
jd-courier:
  image:
    tag: "1.1.0"  # Pin to previous version
```

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

The `/readyz` endpoint performs a database ping with a 2-second timeout. The Kubernetes default probe timeout of 1 second was insufficient, causing false-negative readiness failures even when the application was healthy but the database response took between 1-2 seconds.

With the new 3-second timeout, the probe allows the full database ping to complete before marking the pod as not ready. This reduces spurious readiness flapping during normal database latency variations.

**Migration action:**

None required. The change is applied automatically during upgrade and improves probe reliability. Pods will be less likely to be marked not ready due to transient database latency.

> **Note:** This change affects all four roles (`spb-consumer`, `spb-sender`, `pix-ingress`, `admin`). The probe configuration is defined in the shared `_helpers.tpl` template.

### Migration Job scheduling controls

**What changed:**

The database migration Job now respects the chart's `nodeSelector`, `tolerations`, and `affinity` values:

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

Now the migration Job uses the same scheduling rules as the application Deployments, ensuring it can reach the database and runs on appropriate nodes.

**Migration action:**

No action required if you are not using `nodeSelector`, `tolerations`, or `affinity`.

**If you are using scheduling constraints:**

The migration Job will now automatically use your existing values:

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

The migration Job will now respect these constraints. Verify that your constraints allow the Job to reach the database — if the Job previously succeeded without these constraints, it will continue to work.

> **Important:** If you have very restrictive affinity rules that prevent the migration Job from scheduling, you may need to adjust them. The Job runs once per upgrade and must be able to connect to the database.

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

- `IDP_M2M_CLIENT_SECRET`: Used by single-tenant deployments for Access Manager machine-to-machine authentication
- `M2M_CLIENT_SECRET`: Alternative name for the same credential

If you were accidentally setting either of these in `config`, the chart will now refuse to render with a clear error message.

**Migration action:**

**If you are not setting these keys:**

No action required.

**If you have `IDP_M2M_CLIENT_SECRET` or `M2M_CLIENT_SECRET` in your `config` block:**

1. Remove them from `config`:

```yaml
# WRONG (will now fail to render):
config:
  IDP_M2M_CLIENT_SECRET: "secret-value-here"  # ❌ Remove this
```

2. Add them to your Secret:

```bash
kubectl create secret generic br-jd-courier-secrets \
  --from-literal=LICENSE_KEY='your-license-key' \
  --from-literal=DATABASE_URL='postgresql://...' \
  --from-literal=POSTGRES_PASSWORD='your-db-password' \
  --from-literal=IDP_M2M_CLIENT_SECRET='your-m2m-secret' \
  --dry-run=client -o yaml | kubectl apply -f -
```

3. Ensure your `secrets.existingSecret` references this Secret:

```yaml
secrets:
  existingSecret: "br-jd-courier-secrets"
```

> **Warning:** If you attempt to upgrade with these keys in `config`, Helm will fail with an error message indicating that secret values must be in the Secret, not the ConfigMap.

### Documentation clarifications

**What changed:**

The `values.yaml` comments have been updated to clarify single-tenant secret requirements:

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

Additionally, the `config` block comments now mention single-tenant IDP requirements:

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

And a new comment about IDP declaration:

```yaml
config:
  PLUGIN_AUTH_ENABLED: "true"
  # Single-tenant publishes the Courier's grants at boot; multi-tenant ignores it.
  IDP_DECLARATION_ENABLED: "true"
```

**Why it matters:**

These are documentation-only changes that clarify:

1. Single-tenant deployments require `IDP_M2M_CLIENT_SECRET` and `JD_PASSWORD` in the Secret
2. Single-tenant deployments should set `IDP_DECLARATION_ENABLED: "true"` in config (this was already the default behavior, now explicitly documented)
3. The comment about multi-tenant parsing of `MULTI_TENANT_ENABLED` has been tightened to note that only the exact word `"true"` is accepted (not `1`, `t`, or other case variations)

**Migration action:**

None required. These are clarifications to existing behavior.

**For single-tenant deployments:**

Ensure your Secret includes the required keys:

```bash
kubectl create secret generic br-jd-courier-secrets \
  --from-literal=LICENSE_KEY='your-license-key' \
  --from-literal=DATABASE_URL='postgresql://...' \
  --from-literal=POSTGRES_PASSWORD='your-db-password' \
  --from-literal=IDP_M2M_CLIENT_SECRET='your-m2m-secret' \
  --from-literal=JD_PASSWORD='your-jd-password' \
  --dry-run=client -o yaml | kubectl apply -f -
```

And set the IDP configuration in your values:

```yaml
config:
  PLUGIN_AUTH_ENABLED: "true"
  IDP_DECLARATION_ENABLED: "true"
  PLUGIN_AUTH_HOST: "http://access-manager.auth.svc.cluster.local"
  # ... other IDP_* keys per your Access Manager setup
```

> **Note:** If you are running multi-tenant (`MULTI_TENANT_ENABLED: "true"`), `IDP_DECLARATION_ENABLED` is ignored and you do not need `IDP_M2M_CLIENT_SECRET` or `JD_PASSWORD` in the Secret.

---

## Preview changes before upgrading

```bash
helm diff upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.1.1 -n br-jd-courier
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

---

## Command to upgrade

```bash
helm upgrade br-jd-courier oci://registry-1.docker.io/lerianstudio/br-jd-courier-helm --version 2.1.1 -n br-jd-courier
```
<!-- {% endraw %} -->
