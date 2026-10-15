# Helm Upgrade from v9.5.3 to v9.5.4

# Topics

- **[Fixes](#fixes)**
  - [1. Database Migration Strategy Change](#1-database-migration-strategy-change)
  - [2. Documentation and Comment Updates](#2-documentation-and-comment-updates)
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

# Fixes

### 1. Database Migration Strategy Change

The caradhras service now runs database migrations as an **init container** instead of a separate pre-upgrade/post-install Job. This change improves upgrade reliability and ensures migrations complete before the application starts serving traffic.

**What changed:**

| Component | v9.5.3 | v9.5.4 |
|-----------|--------|--------|
| Migration execution | Separate Job with Helm hooks | Init container in caradhras Deployment |
| Deployment strategy | Uses `auth.deploymentStrategy` | Fixed RollingUpdate with maxSurge=1, maxUnavailable=0 |
| Migration timing | Pre-upgrade/post-install hook | Before each pod starts |
| Concurrency handling | Single Job execution | Advisory lock serializes concurrent pods |

**Why this matters:**

- **Zero-downtime upgrades**: The new strategy ensures a new pod migrates the database before any old pod terminates, preventing service interruption
- **Better rollout control**: Each replica runs migrations in its init container, with concurrent migrations serialized via advisory lock
- **No hook ordering problems**: `helm install --wait` (and Argo CD) no longer wait for a post-install hook that only runs after caradhras is Ready
- **Consistent behavior**: Migration happens on every pod start, not just during Helm lifecycle hooks

**Before (v9.5.3):**

```yaml
# Separate Job resource with Helm hooks
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ printf "%s-migrations" (include "plugin-caradhras.fullname" .) | trunc 63 | trimSuffix "-" }}
  annotations:
    helm.sh/hook: pre-upgrade, post-install
    helm.sh/hook-delete-policy: before-hook-creation
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: "{{ include "caradhras.migrationsImageRepository" . }}:{{ include "caradhras.migrationsImageTag" . }}"
          # ... migration logic
      restartPolicy: OnFailure
```

```yaml
# Deployment used auth.deploymentStrategy
spec:
  strategy:
    {{- toYaml .Values.auth.deploymentStrategy | nindent 4 }}
```

**After (v9.5.4):**

```yaml
# Init container in caradhras Deployment
spec:
  # Fixed strategy for zero-downtime migrations
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      initContainers:
        - name: wait-for-dependencies
          # ... dependency checks
        - name: migrate
          securityContext:
            {{- toYaml .Values.auth.securityContext | nindent 12 }}
          workingDir: /tmp
          image: "{{ include "caradhras.migrationsImageRepository" . }}:{{ include "caradhras.migrationsImageTag" . }}"
          imagePullPolicy: {{ include "caradhras.migrationsImagePullPolicy" . }}
          env:
            - name: POSTGRES_HOST
              valueFrom:
                configMapKeyRef:
                  name: {{ include "plugin-auth.fullname" . }}
                  key: DB_HOST
            # ... other POSTGRES_* env vars
```

**Operational impact:**

1. **Deployment strategy override**: The caradhras Deployment now uses a fixed `RollingUpdate` strategy with `maxSurge: 1` and `maxUnavailable: 0`, regardless of your `auth.deploymentStrategy` setting. This ensures new pods complete migrations before old pods terminate.

2. **Migration execution**: Migrations now run in an init container named `migrate` on every pod start. The migrator uses an advisory lock to serialize concurrent executions, so multiple replicas can safely start simultaneously.

3. **Startup time**: Every caradhras pod runs `migrate` before the caradhras container starts. The run is a quick no-op when the schema is already current. Readiness and liveness probes start only after all init containers finish, so migration time does not count against `initialDelaySeconds`. Probe settings do not need to change.

4. **Registry pull on every pod start**: The `migrate` init container uses `imagePullPolicy: Always` (the `caradhras.migrations.image.pullPolicy` default). Every caradhras pod start (upgrade, scale-out, node replacement, eviction) now pulls `ghcr.io/lerianstudio/caradhras-migrations`, not only upgrades. If your cluster reaches that registry through a restricted egress or a mirror, make sure it is reachable, or caradhras pods cannot start.

5. **Failure behavior**: If a migration fails, the new pod stays in `Init:CrashLoopBackOff` with the migrate error in the `migrate` container log. The old pod keeps serving because `maxUnavailable: 0`. **A failed migration no longer fails `helm upgrade`.** With v9.5.3 the `pre-upgrade` hook Job failed the upgrade. With v9.5.4, `helm upgrade` without `--wait` returns success while the new pod is stuck in Init. If your pipeline relies on the `helm upgrade` exit code to catch a failed migration, add `--wait --timeout <duration>` (or check the rollout, for example `kubectl rollout status deployment/<release>-caradhras`). In Argo CD the application shows as Progressing or Degraded.

6. **Rollback behavior**: `helm rollback` to v9.5.3 restores the old templates, but it does not run migrations. The v9.5.3 Job is a `pre-upgrade`/`post-install` hook, not a rollback hook. Migrations already applied stay in the database.

> **Important:** The old `<release>-caradhras-migrations` Job is **not** removed by the upgrade. It was a Helm hook, and Helm never tracks hook resources in the release, so the last Completed Job stays in the namespace. It is inert. Remove it when convenient:
>
> ```bash
> kubectl delete job <release>-caradhras-migrations -n <namespace>
> ```
>
> If you have monitoring or automation that depends on this Job's existence or status, move it to the `migrate` init container of the caradhras Deployment.

> **Note:** The migration image and configuration (`caradhras.migrations.image.*`) remain unchanged. Only the execution mechanism has changed from Job to init container.

**No configuration changes are required** for most operators. The upgrade will automatically:
- Deploy the new caradhras pods with the migrate init container
- Use the same migration image and database credentials as before

**Action required only if:**

- You have custom monitoring or alerting on the `*-migrations` Job resource → Update to monitor the caradhras Deployment's `migrate` init container
- Your pipeline detects migration failures through the `helm upgrade` exit code → Add `--wait` (see Failure behavior above)
- You set `auth.deploymentStrategy` (for example `Recreate`) → It no longer applies to caradhras. The caradhras rollout needs room for one extra pod (`maxSurge: 1`) in node capacity and in any namespace ResourceQuota
- You want to remove the orphaned `<release>-caradhras-migrations` Job → Delete it manually (see above)

### 2. Documentation and Comment Updates

Several inline comments and error messages have been updated to reflect the migration strategy change. These are documentation improvements with no functional impact.

**What changed:**

- Helper template comments now refer to "caradhras migrate init container" instead of "migrations Job"
- Error messages about the casdoor-migrations image now mention "init container" instead of "migration Job"
- Secret and helper documentation updated to remove references to the separate migrations workload

**Examples:**

| Location | v9.5.3 | v9.5.4 |
|----------|--------|--------|
| `_helpers.tpl` migration image comment | "for the migrations Job image" | "for the caradhras migrate init container image" |
| `_helpers.tpl` error message | "the migration Job injects POSTGRES_* env vars" | "the caradhras migrate init container injects POSTGRES_* env vars" |
| `_helpers.tpl` password helper comment | "Used by auth, caradhras, and migrations/init-user workloads" | "Used by auth, caradhras, and init-user workloads" |
| `secrets.yaml` comment | "read via secretKeyRef by caradhras, migrations, and init-user" | "read via secretKeyRef by caradhras and init-user workloads" |

> **Note:** These are documentation-only changes. No configuration or operational changes are required.

# Preview changes before upgrading

```bash
helm diff upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.4 -n plugin-access-manager
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

# Command to upgrade

```bash
helm upgrade plugin-access-manager oci://registry-1.docker.io/lerianstudio/plugin-access-manager --version 9.5.4 -n plugin-access-manager
```
