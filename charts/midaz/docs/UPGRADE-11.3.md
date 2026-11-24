<!-- {% raw %} -->
# Helm Upgrade from v11.2.2 to v11.3.0

## Topics

- **[Features](#features)**
  - [1. New Tracer partition runner](#1-new-tracer-partition-runner)
  - [2. Partition reconcile hook for Tracer](#2-partition-reconcile-hook-for-tracer)
  - [3. Label name truncation for long resource names](#3-label-name-truncation-for-long-resource-names)
- **[Configuration Reference](#configuration-reference)**
  - [Tracer partition configuration](#tracer-partition-configuration)
- **[Migration Steps](#migration-steps)**
- **[Preview changes before upgrading](#preview-changes-before-upgrading)**
- **[Command to upgrade](#command-to-upgrade)**

## Features

### 1. New Tracer partition runner

Chart v11.3.0 introduces a new **partition runner** for the Tracer component. This scheduled job creates validation record partitions ahead of time and reports health via exit codes.

| Setting | v11.2.2 | v11.3.0 |
|---------|---------|---------|
| `tracer.partition.enabled` | (not present) | `nil` (auto-enabled for tags >= 4.6.0-beta.30) |
| `tracer.partition.schedule` | (not present) | `"0 6 * * *"` |
| `tracer.partition.resources` | (not present) | `{ limits: { cpu: 200m, memory: 128Mi }, requests: { cpu: 50m, memory: 64Mi } }` |

#### What changed

The Tracer now ships with a `/partition` command that pre-creates table partitions for validation records. A new CronJob runs this command on a daily schedule, visiting every active tenant in multi-tenant mode.

**Auto-enablement logic:**

- When `tracer.partition.enabled` is unset (nil), the chart auto-enables the runner for Tracer image tags >= `4.6.0-beta.30` (the first tag shipping the `/partition` command)
- Older tags and non-SemVer tags default to disabled
- Set `tracer.partition.enabled: true` or `false` to override the auto-detection

**Exit codes:**

| Code | Meaning |
|------|---------|
| 0 | Healthy / no partitions needed |
| 1 | Attention required (e.g., partitions created but some tenants need review) |
| 2 | Invalid configuration or runtime error |

#### Default configuration

```yaml
tracer:
  partition:
    enabled:  # unset = auto (on for >= 4.6.0-beta.30)
    schedule: "0 6 * * *"
    timeZone: ""
    activeDeadlineSeconds: 1800
    resources:
      limits:
        cpu: 200m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
```

| Flag | Default | Description |
|------|---------|-------------|
| `enabled` | `nil` (auto) | Run the scheduled runner; unset enables tags >= 4.6.0-beta.30 |
| `schedule` | `"0 6 * * *"` | Cron schedule in `timeZone`, defaulting to 06:00 (outside common managed PostgreSQL maintenance windows) |
| `timeZone` | `""` | IANA time zone for `schedule` (e.g. "America/Sao_Paulo"); empty uses the kube-controller-manager's zone (UTC on most managed clusters) |
| `activeDeadlineSeconds` | `1800` | Hard timeout for one run, in seconds (30 minutes) |

#### Why this matters

Pre-creating partitions prevents runtime latency spikes when the first validation record of a new time period triggers an on-demand partition. The daily schedule ensures partitions exist before peak traffic hours.

The default schedule (`0 6 * * *`) runs at 06:00 in the configured time zone, outside common managed PostgreSQL maintenance windows (typically 00:00–05:00 UTC for AWS RDS, 22:00–02:00 UTC for Azure Database).

> **Important:** Choose a schedule time outside your database's maintenance window. Set `timeZone` to pin the schedule to a specific zone if your cluster's kube-controller-manager runs in a different zone than your database.

#### Disabling the partition runner

If you manage partitions out-of-band or run an older Tracer image:

```yaml
tracer:
  partition:
    enabled: false
```

### 2. Partition reconcile hook for Tracer

Chart v11.3.0 adds a **partition reconcile hook** that runs after Tracer migrations to ensure indexes are created on existing partitions.

| Setting | v11.2.2 | v11.3.0 |
|---------|---------|---------|
| `tracer.partition.reconcile.enabled` | (not present) | `true` |
| `tracer.partition.reconcile.syncWave` | (not present) | `"1"` |
| `tracer.partition.reconcile.activeDeadlineSeconds` | (not present) | `1800` |
| `tracer.partition.reconcile.ttlSecondsAfterFinished` | (not present) | `259200` |

#### What changed

A new Job runs the `/partition reconcile-indexes` command as a post-install/post-upgrade hook (Argo CD Sync hook). This ensures that:

- Empty registries and unpartitioned tables exit 0 (no-op)
- Existing partitions get their indexes reconciled after a schema migration
- A startup error (including licence gateway failures) still fails the hook

**Before (v11.2.2):**

The Tracer migrations Job ran, but no post-migration index reconciliation occurred. Operators had to manually reconcile indexes on existing partitions after schema changes.

**After (v11.3.0):**

```yaml
tracer:
  partition:
    reconcile:
      enabled: true
      syncWave: "1"
      activeDeadlineSeconds: 1800
      ttlSecondsAfterFinished: 259200
```

| Flag | Default | Description |
|------|---------|-------------|
| `enabled` | `true` | Run reconcile-indexes after migration as a Sync hook |
| `syncWave` | `"1"` | Argo CD sync wave (after the migration Job's default wave 0); on plain Helm it runs post-install/post-upgrade with hook weight "10" |
| `activeDeadlineSeconds` | `1800` | Hard timeout for the reconcile Job (30 minutes; a concurrent index build on a large partition can take a while) |
| `ttlSecondsAfterFinished` | `259200` | How long a failed reconcile Job is kept for inspection (3 days); a successful hook Job is deleted at once |

#### Argo CD sync wave ordering

The reconcile Job runs in sync wave `"1"`, after the Tracer migration Job (wave `"0"`) and before the Tracer Deployment (wave `"1"`). On plain Helm, it runs as a post-install/post-upgrade hook with weight `10`.

#### Why this matters

Without index reconciliation, existing partitions created before a schema migration may lack new indexes, causing query performance degradation. The reconcile hook ensures all partitions are consistent with the current schema.

> **Note:** A concurrent index build on a large partition can take several minutes. The default 30-minute timeout accommodates most scenarios, but you may need to increase `activeDeadlineSeconds` for very large datasets.

#### Disabling the reconcile hook

If you manage index reconciliation out-of-band:

```yaml
tracer:
  partition:
    reconcile:
      enabled: false
```

### 3. Label name truncation for long resource names

Chart v11.3.0 introduces automatic label name truncation to prevent Kubernetes label validation errors when resource names exceed 63 characters.

#### What changed

The `app.kubernetes.io/name` label is constructed as `<midaz.name>-<name>`. When this exceeds 63 characters, the chart now automatically truncates it to:

```
<prefix-27-chars>-<8-char-hash>-<tail-26-chars>
```

This ensures the label stays within Kubernetes' 63-character limit while remaining unique and recognizable.

**Before (v11.2.2):**

```yaml
# _helpers.tpl
{{- define "midaz.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "midaz.name" .context }}-{{ .name }}
{{- end }}
{{- end }}
```

Long resource names (e.g., `midaz-tracer-partition-reconcile-4-6-0-beta-30-abcd1234`) would produce labels exceeding 63 characters, causing validation errors.

**After (v11.3.0):**

```yaml
# _helpers.tpl
{{- define "midaz.labelName" -}}
{{- $full := printf "%s-%s" (include "midaz.name" .context) .name -}}
{{- if and .fit (gt (len $full) 63) -}}
{{- printf "%s-%s-%s" ($full | trunc 27 | trimAll "-._") (sha256sum $full | trunc 8) ($full | trunc -26 | trimAll "-._") -}}
{{- else -}}
{{- $full -}}
{{- end -}}
{{- end }}

{{- define "midaz.selectorLabels" -}}
{{- if .name -}}
app.kubernetes.io/name: {{ include "midaz.labelName" . }}
{{- end }}
{{- end }}
```

The new `midaz.labelName` helper:

1. Constructs the full name
2. If `.fit` is true and the name exceeds 63 characters, truncates it to a prefix, hash, and tail
3. Otherwise, returns the full name unchanged

#### Operational impact

This change is **transparent** to operators. No action is required. Existing resources with short names are unaffected. New resources with long names (e.g., the Tracer partition CronJob and reconcile Job) will automatically use truncated labels.

> **Note:** The truncation logic only applies when the `.fit` parameter is explicitly passed to the label helper. Existing resources (ledger, tracer Deployments, Services) continue to use their original names.

#### Example

For a Tracer partition reconcile Job with a long image tag:

**Full name:**

```
midaz-tracer-partition-reconcile-4-6-0-beta-30-abcd1234
```

**Truncated label (if > 63 chars):**

```
midaz-tracer-partition-rec-a1b2c3d4-4-6-0-beta-30-abcd1234
```

The 8-character hash (`a1b2c3d4`) ensures uniqueness even when multiple resources share the same prefix and tail.

## Configuration Reference

### Tracer partition configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `tracer.partition.enabled` | bool | `nil` (auto) | Run the scheduled partition runner; unset enables tags >= 4.6.0-beta.30 |
| `tracer.partition.schedule` | string | `"0 6 * * *"` | Cron schedule in `timeZone`, defaulting to 06:00 |
| `tracer.partition.timeZone` | string | `""` | IANA time zone for `schedule` (e.g. "America/Sao_Paulo"); empty uses kube-controller-manager's zone |
| `tracer.partition.activeDeadlineSeconds` | int | `1800` | Hard timeout for one run, in seconds |
| `tracer.partition.reconcile.enabled` | bool | `true` | Run reconcile-indexes after migration as a Sync hook |
| `tracer.partition.reconcile.syncWave` | string | `"1"` | Argo CD sync wave (after migration Job's wave 0) |
| `tracer.partition.reconcile.activeDeadlineSeconds` | int | `1800` | Hard timeout for the reconcile Job, in seconds |
| `tracer.partition.reconcile.ttlSecondsAfterFinished` | int | `259200` | How long a failed reconcile Job is kept for inspection (3 days) |
| `tracer.partition.resources.limits.cpu` | string | `"200m"` | CPU limit for the partition runner |
| `tracer.partition.resources.limits.memory` | string | `"128Mi"` | Memory limit for the partition runner |
| `tracer.partition.resources.requests.cpu` | string | `"50m"` | Minimum CPU request for the partition runner |
| `tracer.partition.resources.requests.memory` | string | `"64Mi"` | Minimum memory request for the partition runner |

## Migration Steps

1. **Review the Tracer partition runner schedule.** The default schedule runs at 06:00 in the kube-controller-manager's time zone. If your database has a maintenance window near this time, adjust the schedule:

   ```yaml
   tracer:
     partition:
       schedule: "0 8 * * *"  # 08:00 instead of 06:00
       timeZone: "America/Sao_Paulo"
   ```

2. **Optionally disable the partition runner.** If you manage partitions out-of-band or run an older Tracer image:

   ```yaml
   tracer:
     partition:
       enabled: false
   ```

3. **Optionally disable the reconcile hook.** If you manage index reconciliation out-of-band:

   ```yaml
   tracer:
     partition:
       reconcile:
         enabled: false
   ```

4. **Run `helm dependency update` if you maintain a local chart copy:**

   ```bash
   helm dependency update charts/midaz
   ```

> **Note:** No action is required for the label truncation feature. It applies automatically to new resources with long names.

## Preview changes before upgrading

```bash
helm diff upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.3.0
```

> **Note:** Requires the [helm-diff plugin](https://github.com/databus23/helm-diff). Install with: `helm plugin install https://github.com/databus23/helm-diff`

## Command to upgrade

```bash
helm upgrade midaz oci://registry-1.docker.io/lerianstudio/midaz-helm -n midaz --version 11.3.0
```
<!-- {% endraw %} -->
